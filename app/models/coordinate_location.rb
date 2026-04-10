# frozen_string_literal: true

class CoordinateLocation
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :latitude, :decimal
  attribute :longitude, :decimal

  def initialize(latitude:, longitude:)
    super(latitude: latitude.to_d, longitude: longitude.to_d)

    @reverse_geocoded = false
  end

  def name
    @name ||= reverse_geocode_display_name
  end

  def full_name
    @full_name ||= reverse_geocode_full_name
  end

  def slug
    coordinates_param
  end

  def emoji_flag
    country&.emoji_flag || "📍"
  end

  def path
    Router.coordinates_path(coordinates: coordinates_param)
  end

  def past_path
    Router.coordinates_past_index_path(coordinates: coordinates_param)
  end

  def users_path
    Router.coordinates_users_path(coordinates: coordinates_param)
  end

  def cities_path
    nil
  end

  def stamps_path
    nil
  end

  def map_path
    Router.coordinates_map_index_path(coordinates: coordinates_param)
  end

  def has_routes?
    true
  end

  def events
    @events ||= nearby_events_query
  end

  def users
    @users ||= nearby_users_query
  end

  def stamps
    []
  end

  def events_count
    events.count
  end

  def users_count
    users.count
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def coordinates
    return nil unless geocoded?

    [latitude, longitude]
  end

  def to_coordinates
    coordinates
  end

  def bounds
    return nil unless geocoded?

    offset = 1.0

    {
      southwest: [longitude.to_f - offset, latitude.to_f - offset],
      northeast: [longitude.to_f + offset, latitude.to_f + offset]
    }
  end

  def to_location
    Location.new(
      city: reverse_geocode_city,
      state_code: reverse_geocode_state,
      country_code: country_code,
      latitude: latitude,
      longitude: longitude,
      raw_location: full_name
    )
  end

  def alpha2
    country_code
  end

  def country_code
    @country_code ||= reverse_geocode_data&.country_code
  end

  def country
    return nil unless country_code.present?

    @country ||= Country.find_by(country_code: country_code)
  end

  def continent
    country&.continent
  end

  def nearby_users(radius_km: 100, limit: 12, exclude_ids: [])
    return [] unless coordinates.present?

    User.geocoded
      .near(coordinates, radius_km, units: :km)
      .where.not(id: exclude_ids)
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

    scope = Event.includes(:series, :participants).where.not(latitude: nil, longitude: nil)
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

  private

  def coordinates_param
    "#{latitude},#{longitude}"
  end

  def reverse_geocode_data
    return @reverse_geocode_data if @reverse_geocoded

    @reverse_geocoded = true

    @reverse_geocode_data = Geocoder.search(coordinates).first
  end

  def reverse_geocode_display_name
    data = reverse_geocode_data

    return "#{latitude}, #{longitude}" unless data

    data.city.presence || data.state.presence || data.country.presence || "#{latitude}, #{longitude}"
  end

  def reverse_geocode_full_name
    data = reverse_geocode_data

    return "#{latitude}, #{longitude}" unless data

    parts = [data.city, data.state, data.country].compact.reject(&:blank?)

    parts.any? ? parts.join(", ") : "#{latitude}, #{longitude}"
  end

  def reverse_geocode_city
    reverse_geocode_data&.city
  end

  def reverse_geocode_state
    reverse_geocode_data&.state
  end

  def nearby_events_query
    return Event.none unless coordinates.present?

    lat_range, lon_range = bounding_box_for_radius(250)

    Event.includes(:series)
      .where(latitude: lat_range, longitude: lon_range)
      .order(start_date: :desc)
  end

  def nearby_users_query
    return User.none unless coordinates.present?

    lat_range, lon_range = bounding_box_for_radius(100)

    User.indexable
      .geocoded
      .where(latitude: lat_range, longitude: lon_range)
  end

  def bounding_box_for_radius(radius_km)
    lat_delta = radius_km / 111.0
    lon_delta = radius_km / (111.0 * Math.cos(latitude.to_f * Math::PI / 180))

    lat_range = (latitude.to_f - lat_delta)..(latitude.to_f + lat_delta)
    lon_range = (longitude.to_f - lon_delta)..(longitude.to_f + lon_delta)

    [lat_range, lon_range]
  end

  class << self
    def from_param(param)
      return nil unless param.present?

      lat, lon = param.split(",").map(&:to_f)

      return nil unless lat.present? && lon.present?
      return nil unless lat.between?(-90, 90) && lon.between?(-180, 180)

      new(latitude: lat, longitude: lon)
    end
  end
end
