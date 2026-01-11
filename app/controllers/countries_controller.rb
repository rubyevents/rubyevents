class CountriesController < ApplicationController
  include EventMapMarkers
  include GeoMapLayers

  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @countries_by_continent = Event.distinct
      .where.not(country_code: [nil, ""])
      .pluck(:country_code)
      .filter_map { |code| Country.find_by(country_code: code) }
      .group_by(&:continent)
      .sort_by { |continent, _| continent&.name || "ZZ" }
      .to_h

    @events_by_country = Event.includes(:series)
      .where.not(country_code: [nil, ""])
      .grouped_by_country
      .to_h

    @users_by_country = User.indexable.geocoded
      .group(:country_code)
      .count
      .transform_keys { |code| Country.find_by(country_code: code) }
      .compact

    @event_map_markers = event_map_markers
  end

  def show
    @country = Country.find(params[:country])

    if @country.blank?
      redirect_to countries_path
      return
    end

    @events = @country.events.includes(:series).order(start_date: :desc)
    @cities = @country.cities.order(:name)

    @users = @country.users
    @stamps = @country.stamps
    @continent = @country.continent
    @location = @country

    upcoming_events = @events.upcoming.to_a

    if @country.uk_nation?
      @parent_country = @country.parent_country
      nation_event_ids = @events.pluck(:id)
      @country_events = @parent_country.events.includes(:series).where.not(id: nation_event_ids).upcoming
    end

    if upcoming_events.empty? && @continent.present?
      exclude_codes = [@country.alpha2]
      exclude_codes << @parent_country&.alpha2 if @parent_country.present?
      @continent_events = continent_upcoming_events(exclude_country_codes: exclude_codes.compact)
    end

    all_events_for_map = upcoming_events.select(&:geocoded?)
    all_events_for_map += (@country_events || []).to_a.select(&:geocoded?)
    all_events_for_map += (@continent_events || []).to_a.select(&:geocoded?)

    @event_map_markers = event_map_markers(all_events_for_map)
    @geo_layers = build_sidebar_geo_layers(upcoming_events)
  end

  def filter_events_by_time(events)
    events.select(&:upcoming?)
  end

  def find_nearby_users(country)
    return [] unless country.respond_to?(:alpha2)

    events_with_coords = Event.where(country_code: country.alpha2)
      .where.not(latitude: nil, longitude: nil)
      .limit(10)

    return [] if events_with_coords.empty?

    avg_lat = events_with_coords.average(:latitude)
    avg_lng = events_with_coords.average(:longitude)

    return [] unless avg_lat && avg_lng

    User.indexable
      .where.not(country_code: country.alpha2)
      .where.not(latitude: nil)
      .near([avg_lat, avg_lng], 500, units: :km)
      .limit(20)
      .to_a
  rescue => e
    Rails.logger.warn "Error finding nearby users for #{country.name}: #{e.message}"
    []
  end

  private

  def continent_upcoming_events(exclude_country_codes: [])
    return [] unless @continent.present?

    continent_country_codes = @continent.countries.map(&:alpha2) - exclude_country_codes

    Event.includes(:series)
      .where(country_code: continent_country_codes)
      .upcoming
  end
end
