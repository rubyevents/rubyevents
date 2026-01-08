class City
  include Locatable

  attr_reader :name, :city, :slug, :country_code, :state_code, :latitude, :longitude

  class << self
    def all
      Rails.cache.fetch("cities/all", expires_in: 1.hour) { build_all }
    end

    def for_country(country_code)
      all.select { |city| city.country_code == country_code.upcase }
    end

    def for_state(state)
      all.select { |city| city.country_code == state.country.alpha2 && city.state_code == state.code }
    end

    def featured_slugs
      @featured_slugs ||= FeaturedCity.pluck(:slug).to_set
    end

    def clear_cache!
      Rails.cache.delete("cities/all")
      @featured_slugs = nil
    end

    private

    def build_all
      cities = {}

      Event.where.not(city: nil).where.not(country_code: nil).find_each do |event|
        key = "#{event.city.parameterize}-#{event.country_code.downcase}"
        next if cities[key]

        cities[key] = {
          name: event.city,
          slug: event.city.parameterize,
          state_code: event.state,
          country_code: event.country_code,
          latitude: event.latitude,
          longitude: event.longitude
        }
      end

      User.where.not(city: nil).where.not(country_code: nil).find_each do |user|
        key = "#{user.city.parameterize}-#{user.country_code.downcase}"

        if cities[key]
          if cities[key][:latitude].nil? && user.latitude.present?
            cities[key][:latitude] = user.latitude
            cities[key][:longitude] = user.longitude
          end
        else
          cities[key] = {
            name: user.city,
            slug: user.city.parameterize,
            state_code: user.state,
            country_code: user.country_code,
            latitude: user.latitude,
            longitude: user.longitude
          }
        end
      end

      cities.values.map do |data|
        new(
          name: data[:name],
          slug: data[:slug],
          country_code: data[:country_code],
          state_code: data[:state_code],
          latitude: data[:latitude],
          longitude: data[:longitude]
        )
      end.sort_by { |c| -(c.events_count + c.users_count) }
    end
  end

  def initialize(name:, slug:, country_code:, state_code: nil, latitude: nil, longitude: nil)
    @slug = slug
    @country_code = country_code
    @state_code = state_code
    @latitude = latitude
    @longitude = longitude
    @city = find_actual_city_name
    @name = @city || name
  end

  def country
    @country ||= Country.find_by(country_code: country_code)
  end

  def state
    return nil unless state_code.present? && State.supported_country?(country)

    @state ||= State.find_by_code(state_code, country: country)
  end

  def events
    @events ||= begin
      matching_cities = find_matching_cities_from_events
      scope = Event.where(city: matching_cities, country_code: country_code)
      scope = scope.where(state: [state_code, state&.name].compact) if state_code.present?

      scope
    end
  end

  def users
    @users ||= begin
      matching_cities = find_matching_cities_from_users
      scope = User.where(city: matching_cities, country_code: country_code)
      scope = scope.where(state: [state_code, state&.name].compact) if state_code.present?

      scope
    end
  end

  private

  def find_actual_city_name
    event = base_event_scope.find { |event| event.city&.parameterize == slug }
    return event.city if event

    user = base_user_scope.find { |user| user.city&.parameterize == slug }
    return user.city if user

    slug.tr("-", " ").titleize
  end

  def find_matching_cities_from_events
    base_event_scope.select { |e| e.city&.parameterize == slug }.map(&:city).uniq
  end

  def find_matching_cities_from_users
    base_user_scope.select { |u| u.city&.parameterize == slug }.map(&:city).uniq
  end

  def base_event_scope
    scope = Event.where(country_code: country_code).where.not(city: nil)
    scope = scope.where(state: [state_code, State.find_by_code(state_code)&.name].compact) if state_code.present?

    scope
  end

  def base_user_scope
    scope = User.where(country_code: country_code).where.not(city: nil)
    scope = scope.where(state: [state_code, State.find_by_code(state_code)&.name].compact) if state_code.present?

    scope
  end

  public

  def path
    return Router.city_path(slug) if featured?

    if state_code.present? && state.present?
      Router.city_with_state_path(country.code, state.slug, slug)
    else
      Router.city_by_country_path(country.code, slug)
    end
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def coordinates
    return nil unless geocoded?

    [latitude, longitude]
  end

  def feature!
    coords = geocode

    FeaturedCity.find_or_create_by!(slug: slug) do |featured|
      featured.name = name
      featured.city = city
      featured.country_code = country_code
      featured.state_code = state_code
      featured.latitude = coords&.first
      featured.longitude = coords&.last
    end
  end

  def geocode
    query = [city, state&.name, country&.name].compact.join(", ")
    result = Geocoder.search(query).first

    result ? [result.latitude, result.longitude] : nil
  end

  def featured?
    self.class.featured_slugs.include?(slug)
  end

  def events_count
    @events_count ||= events.count
  end

  def users_count
    @users_count ||= users.count
  end

  def location_string
    if country&.alpha2 == "US" && state_code.present?
      "#{name}, #{state_code}"
    else
      "#{name}, #{country&.name}"
    end
  end

  def alpha2
    country_code
  end

  def continent
    country&.continent
  end

  def bounds
    return nil unless geocoded?

    offset = 0.5

    {
      southwest: [longitude - offset, latitude - offset],
      northeast: [longitude + offset, latitude + offset]
    }
  end

  def stamps
    @stamps ||= begin
      event_stamps = events.flat_map { |event| Stamp.for_event(event) }
      country_stamp = Stamp.for_country(country_code)
      stamps = event_stamps
      stamps << country_stamp if country_stamp

      stamps.uniq { |s| s.code }
    end
  end

  def nearby_users(radius_km: 100, limit: 12, exclude_ids: [])
    return [] unless coordinates.present?

    User.geocoded
      .near(coordinates, radius_km, units: :km)
      .where.not(id: exclude_ids)
      .preloaded
      .limit(limit)
      .map do |user|
        distance = Geocoder::Calculations.distance_between(
          coordinates,
          [user.latitude, user.longitude],
          units: :km
        )
        {user: user, distance_km: distance.round}
      end
      .sort_by { |u| u[:distance_km] }
  end

  def nearby_events(radius_km: 250, limit: 12, exclude_ids: [])
    return [] unless coordinates.present?

    scope = Event.includes(:series, :participants).geocoded.where.not(city: city)
    scope = scope.where.not(id: exclude_ids) if exclude_ids.any?

    scope.map do |event|
      distance = Geocoder::Calculations.distance_between(
        coordinates,
        [event.latitude, event.longitude],
        units: :km
      )

      {event: event, distance_km: distance.round} if distance <= radius_km
    end
      .compact
      .sort_by { |e| e[:event].start_date || Time.at(0).to_date }
      .last(limit)
      .reverse
  end

  def with_coordinates
    return self if geocoded?

    coords = find_coordinates_from_records
    return self unless coords

    City.new(
      name: name,
      slug: slug,
      country_code: country_code,
      state_code: state_code,
      latitude: coords[0],
      longitude: coords[1]
    )
  end

  private

  def find_coordinates_from_records
    event = events.geocoded.first
    return event.to_coordinates if event

    user = users.geocoded.first
    return user.to_coordinates if user

    nil
  end

  def geocode_coordinates
    find_coordinates_from_records || geocode
  end
end
