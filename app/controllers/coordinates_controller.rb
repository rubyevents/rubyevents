# frozen_string_literal: true

class CoordinatesController < ApplicationController
  include EventMapMarkers

  skip_before_action :authenticate_user!

  def index
    return if params[:q].blank?

    result = Geocoder.search(params[:q]).first
    lat = result&.latitude
    lon = result&.longitude

    if lat.present? && lon.present?
      redirect_to coordinates_path(coordinates: "#{lat},#{lon}")
    else
      flash.now[:alert] = "Could not find location: #{params[:q]}"
    end
  end

  def show
    @location = CoordinateLocation.from_param(params[:coordinates])

    if @location.blank?
      redirect_to root_path
      return
    end

    load_location_data
  end

  private

  def load_location_data
    @events = @location.events.includes(:series).order(start_date: :desc)
    @users = @location.users

    @nearby_users = @location.nearby_users(exclude_ids: @users.pluck(:id))
    @nearby_events = @location.nearby_events(exclude_ids: @events.pluck(:id))

    @country = @location.country
    @continent = @location.continent

    all_events_for_map = @events.select(&:upcoming?).select(&:geocoded?)
    all_events_for_map += @nearby_events.select { |n| n[:event].upcoming? }.map { |n| n[:event] }.select(&:geocoded?)

    @event_map_markers = event_map_markers(all_events_for_map)
    @geo_layers = build_geo_layers(all_events_for_map)
  end

  def build_geo_layers(events)
    coordinate_pin = {
      type: "coordinate",
      name: @location.name,
      longitude: @location.longitude,
      latitude: @location.latitude
    }

    [{
      id: "geo-coordinate",
      label: @location.name,
      emoji: "📍",
      markers: event_map_markers(events),
      cityPin: coordinate_pin,
      alwaysVisible: true,
      visible: true,
      group: "geo"
    }]
  end
end
