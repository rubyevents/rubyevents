# frozen_string_literal: true

class ContinentsController < ApplicationController
  include EventMapMarkers
  include GeoMapLayers

  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @continents = Continent.all.sort_by(&:name)

    @events_by_continent = Event.includes(:series)
      .where.not(country_code: [nil, ""])
      .group_by(&:country)
      .transform_keys(&:continent)
      .compact

    @users_by_continent = User.indexable.geocoded
      .group(:country_code)
      .count
      .group_by { |code, _| Country.find_by(country_code: code)&.continent }
      .transform_values { |codes| codes.sum { |_, count| count } }
      .compact

    @event_map_markers = event_map_markers
  end

  def show
    @continent = Continent.find(params[:continent])
    redirect_to(continents_path) and return if @continent.blank?

    @events = @continent.events.includes(:series).order(start_date: :desc)
    @countries = @continent.countries.sort_by(&:name)
    @users = @continent.users
    @stamps = @continent.stamps
    @location = @continent

    upcoming_events = @events.upcoming.to_a
    @events_by_country = upcoming_events.group_by(&:country).compact.sort_by { |country, _| country&.name.to_s }.to_h
    @event_map_markers = event_map_markers(upcoming_events.select(&:geocoded?))
    @geo_layers = build_sidebar_geo_layers(upcoming_events)
  end
end
