# frozen_string_literal: true

class Locations::BaseController < ApplicationController
  include EventMapMarkers

  skip_before_action :authenticate_user!

  before_action :set_location

  private

  def set_location
    if params[:online].present?
      set_online
    elsif params[:continent_continent].present?
      set_continent
    elsif params[:country_country].present?
      set_country
    elsif params[:state_alpha2].present? && params[:state_slug].present?
      set_state
    elsif params[:slug].present?
      set_featured_city
    elsif params[:state].present?
      set_city_with_state
    elsif params[:alpha2].present?
      set_city_by_country
    else
      redirect_to root_path
    end
  end

  def set_online
    @location = OnlineLocation.instance
  end

  def set_continent
    @location = @continent = Continent.find(params[:continent_continent])

    redirect_to(continents_path) and return unless @continent.present?
  end

  def set_country
    @location = @country = Country.find(params[:country_country])
    redirect_to(countries_path) and return unless @country.present?

    @continent = Continent.find_by_name(@country.continent)
  end

  def set_state
    @country = Country.find_by(country_code: params[:state_alpha2].upcase)
    redirect_to(countries_path) and return unless @country.present?

    @location = @state = State.find(country: @country, term: params[:state_slug])
    redirect_to(country_path(@country)) and return unless @state.present?

    @continent = Continent.find_by_name(@country.continent)
  end

  def set_featured_city
    @location = @city = FeaturedCity.find_by(slug: params[:slug])
    redirect_to(cities_path) and return unless @city.present?

    @country = Country.find_by(country_code: @city.country_code)
    @continent = Continent.find_by_name(@country&.continent)

    if @city.state_code.present? && @country.present? && State.supported_country?(@country)
      @state = State.find(country: @country, term: @city.state_code)
    end
  end

  def set_city_by_country
    @country = Country.find_by(country_code: params[:alpha2].upcase)
    redirect_to(countries_path) and return unless @country.present?

    @continent = Continent.find_by_name(@country.continent)

    @city_slug = params[:city]
    @city_name = @city_slug.tr("-", " ").titleize

    featured = FeaturedCity.find_by(slug: @city_slug)
    featured ||= FeaturedCity.find_for(city: @city_name, country_code: @country.alpha2)

    if featured.present?
      redirect_to send(redirect_path_helper, featured.slug), status: :moved_permanently
      return
    end

    @location = @city = City.new(
      name: @city_name,
      slug: @city_slug,
      country_code: @country.alpha2,
      state_code: nil
    ).with_coordinates
  end

  def set_city_with_state
    @country = Country.find_by(country_code: params[:alpha2].upcase)
    redirect_to(countries_path) and return unless @country.present?

    @state = State.find(country: @country, term: params[:state])
    redirect_to(country_path(@country)) and return unless @state.present?

    @city_slug = params[:city]
    @city_name = @city_slug.tr("-", " ").titleize

    featured = FeaturedCity.find_by(slug: @city_slug)

    featured ||= FeaturedCity.find_for(
      city: @city_name,
      country_code: @country.alpha2,
      state_code: @state.code
    )

    if featured.present?
      redirect_to send(redirect_path_helper, featured.slug), status: :moved_permanently
      return
    end

    @continent = Continent.find_by_name(@country.continent)

    @location = @city = City.new(
      name: @city_name,
      slug: @city_slug,
      country_code: @country.alpha2,
      state_code: @state.code
    ).with_coordinates
  end

  def redirect_path_helper
    :city_path
  end

  def location_events
    @location_events ||= @location.events.includes(:series).order(start_date: :desc)
  end

  def upcoming_events
    @upcoming_events ||= location_events.upcoming.reorder(start_date: :asc)
  end

  def past_events
    @past_events ||= location_events.past.reorder(end_date: :desc)
  end

  def location_users
    @location_users ||= if city? || state?
      @location.users.geocoded.order(talks_count: :desc).preloaded
    else
      @location.users.canonical.order(talks_count: :desc).preloaded
    end
  end

  def load_nearby_data
    return unless city? && @city.geocoded?

    @nearby_users = @city.nearby_users(exclude_ids: location_users.pluck(:id))
  end

  def load_events_by_city
    return unless country? || state?

    events = @location.events.includes(:series)

    country_code = country? ? @location.alpha2 : @country&.alpha2
    featured_cities = FeaturedCity.where(country_code: country_code)
    featured_city_names = featured_cities.pluck(:city).map(&:downcase).to_set

    @events_by_city = events
      .select { |event| event.location.present? }
      .reject { |event| featured_city_names.include?(event.city&.downcase) }
      .group_by(&:location)
      .sort_by { |city, _events| city }
      .to_h
  end

  def load_nearby_events
    return unless city? && @city.geocoded? && upcoming_events.empty?

    @nearby_events = @city.nearby_events(exclude_ids: [])
      .select { |n| n[:event].upcoming? }
  end

  def country_upcoming_events(exclude_ids: [])
    return [] unless city?

    Event.includes(:series)
      .where(country_code: @city.country_code)
      .where.not(city: @city.city)
      .where.not(id: exclude_ids)
      .upcoming
  end

  def continent_upcoming_events(exclude_country_codes: [])
    return [] unless @continent.present?

    continent_country_codes = @continent.countries.map(&:alpha2) - exclude_country_codes

    Event.includes(:series)
      .where(country_code: continent_country_codes)
      .upcoming
  end

  def online?
    @location.is_a?(OnlineLocation)
  end

  def city?
    @location.is_a?(FeaturedCity) || @location.is_a?(City)
  end

  def state?
    @location.is_a?(State)
  end

  def country?
    @location.is_a?(Country) || @location.is_a?(UKNation)
  end

  def continent?
    @location.is_a?(Continent)
  end

  def location_view_prefix
    case @location
    when OnlineLocation then "online"
    when Continent then "continents"
    when Country, UKNation then "countries"
    when State then "states"
    else "cities"
    end
  end

  def render_location_view(action)
    return redirect_to(root_path) unless @location.present?

    render "#{location_view_prefix}/#{action}/index"
  end
end
