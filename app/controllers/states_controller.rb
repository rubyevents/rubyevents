class StatesController < ApplicationController
  include EventMapMarkers
  include GeoMapLayers

  skip_before_action :authenticate_user!, only: %i[index country_index show]

  def index
    @countries_with_states = State::SUPPORTED_COUNTRIES.map do |code|
      Country.find_by(country_code: code)
    end.compact
  end

  def country_index
    @country = Country.find_by(country_code: params[:alpha2].upcase)

    if @country.blank?
      redirect_to states_path
      return
    end

    @states = @country.states
  end

  def show
    @country = Country.find_by(country_code: params[:state_alpha2].upcase)

    if @country.blank?
      redirect_to states_path
      return
    end

    @state = State.find(country: @country, term: params[:state_slug])

    if @state.blank?
      redirect_to country_states_path(alpha2: @country.code)
      return
    end

    @continent = @country.continent

    @events = @state.events.includes(:series).order(start_date: :desc)
    @cities = @state.cities.order(:name)

    @users = @state.users
    @stamps = @state.stamps

    @country_events = Event.includes(:series)
      .where(country_code: @country.alpha2)
      .where.not(state_code: [@state.code, @state.name])
      .upcoming
      .limit(8)

    continent_country_codes = @continent&.countries&.map(&:alpha2) || []
    @continent_events = Event.includes(:series)
      .where(country_code: continent_country_codes - [@country.alpha2])
      .upcoming
      .limit(8)

    @location = @state
    @event_map_markers = event_map_markers(@events)

    upcoming_events = @events.upcoming.to_a

    @geo_layers = build_sidebar_geo_layers(upcoming_events)
  end

  private

  def filter_events_by_time(events)
    events.select(&:upcoming?)
  end
end
