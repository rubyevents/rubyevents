class CitiesController < ApplicationController
  include EventMapMarkers
  include GeoMapLayers

  skip_before_action :authenticate_user!, only: %i[index show show_by_country show_with_state]

  def index
    @cities = City.all
  end

  def show
    @city = City.find_by(slug: params[:slug])

    if @city.blank?
      redirect_to cities_path
      return
    end

    load_city_data
  end

  def show_by_country
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to countries_path
      return
    end

    @city_slug = params[:city]
    @city_name = @city_slug.tr("-", " ").titleize

    @city = City.find_by(slug: @city_slug)
    @city ||= City.find_for(city: @city_name, country_code: @country.alpha2)

    if @city.present?
      redirect_to city_path(@city.slug), status: :moved_permanently
    else
      redirect_to country_path(@country)
    end
  end

  def show_with_state
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to countries_path
      return
    end

    @state = State.find(country: @country, term: params[:state])

    if @state.blank?
      redirect_to country_path(@country)
      return
    end

    @city_slug = params[:city]
    @city_name = @city_slug.tr("-", " ").titleize

    @city = City.find_by(slug: @city_slug)
    @city ||= City.find_for(city: @city_name, country_code: @country.alpha2, state_code: @state.code)

    if @city.present?
      redirect_to city_path(@city.slug), status: :moved_permanently
    else
      redirect_to state_path(state_alpha2: @country.code, state_slug: @state.slug)
    end
  end

  private

  def load_city_data
    @events = @city.events.includes(:series).order(start_date: :desc)
    @users = @city.users
    @stamps = @city.stamps

    upcoming_events = @events.upcoming.to_a

    if @city.geocoded?
      @nearby_users = @city.nearby_users(exclude_ids: @users.pluck(:id))
      @nearby_events = @city.nearby_events(exclude_ids: @events.pluck(:id))
    end

    nearby_event_ids = (@nearby_events || []).map { |n| n[:event].id }
    exclude_ids = @events.pluck(:id) + nearby_event_ids

    @country_events = Event.includes(:series)
      .where(country_code: @city.country_code)
      .where.not(city: @city.name)
      .where.not(id: exclude_ids)
      .upcoming

    @country = @city.country
    @continent = @country&.continent

    if @country_events.empty? && @continent.present?
      @continent_events = continent_upcoming_events(exclude_country_codes: [@city.country_code])
    end

    @location = @city
    @state = @city.state_code.present? ? State.find(country: @country, term: @city.state_code) : nil

    if @state.present?
      city_user_ids = @users.pluck(:id)
      nearby_user_ids = (@nearby_users || []).map { |n| n.is_a?(Hash) ? n[:user].id : n.id }
      exclude_ids = city_user_ids + nearby_user_ids
      @state_users = @state.users.where.not(id: exclude_ids).limit(24)
    end

    all_events_for_map = upcoming_events.select(&:geocoded?)

    all_events_for_map += (@nearby_events || []).select { |n| n[:event].upcoming? }.map { |n| n[:event] }.select(&:geocoded?)
    all_events_for_map += @country_events.geocoded.to_a
    all_events_for_map += (@continent_events || []).to_a.select(&:geocoded?)

    @event_map_markers = event_map_markers(all_events_for_map)
    @geo_layers = build_sidebar_geo_layers(upcoming_events)
  end

  def filter_events_by_time(events)
    events.select(&:upcoming?)
  end

  def continent_upcoming_events(exclude_country_codes: [])
    return [] unless @continent.present?

    continent_country_codes = @continent.countries.map(&:alpha2) - exclude_country_codes

    Event.includes(:series)
      .where(country_code: continent_country_codes)
      .upcoming
  end
end
