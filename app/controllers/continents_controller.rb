# frozen_string_literal: true

class ContinentsController < ApplicationController
  include EventMapMarkers
  include GeoMapLayers

  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @continents = Continent.all.sort_by(&:name)

    @events_by_continent = Event.includes(:series)
      .where.not(country_code: [nil, ""])
      .group_by { |e| Country.find_by(country_code: e.country_code)&.continent }
      .transform_keys { |name| Continent.find_by_name(name) }
      .compact

    @users_by_continent = User.geocoded
      .group(:country_code)
      .count
      .group_by { |code, _| Country.find_by(country_code: code)&.continent }
      .transform_values { |codes| codes.sum { |_, count| count } }
      .transform_keys { |name| Continent.find_by_name(name) }
      .compact

    @event_map_markers = event_map_markers
  end

  def show
    @continent = Continent.find(params[:continent])

    if @continent.blank?
      redirect_to continents_path
      return
    end

    @events = @continent.events.includes(:series).order(start_date: :desc)
    @countries = @continent.countries.sort_by(&:name)

    @events_by_country = @events
      .select { |event| event.country_code.present? }
      .group_by { |event| Country.find_by(country_code: event.country_code) }
      .compact
      .sort_by { |country, _| country&.name.to_s }
      .to_h

    @users = @continent.users.geocoded.order(talks_count: :desc)
    @stamps = @continent.stamps
    @location = @continent

    upcoming_events = @events.upcoming.to_a
    @event_map_markers = event_map_markers(upcoming_events.select(&:geocoded?))
    @geo_layers = build_sidebar_geo_layers(upcoming_events)
  end

  private

  def filter_events_by_time(events)
    events.select(&:upcoming?)
  end
end
