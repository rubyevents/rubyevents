# frozen_string_literal: true

class Locations::PastController < Locations::BaseController
  include GeoMapLayers

  def index
    @events = past_events
    @users = location_users
    @event_map_markers = event_map_markers(@events.geocoded)

    load_nearby_data if city?
    load_cities if country? || state?

    @geo_layers = build_sidebar_geo_layers(@events)

    render_location_view("past")
  end

  private

  def filter_events_by_time(events)
    events.select(&:past?)
  end

  def redirect_path_helper
    :city_past_index_path
  end
end
