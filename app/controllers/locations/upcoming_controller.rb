# frozen_string_literal: true

class Locations::UpcomingController < Locations::BaseController
  include GeoMapLayers

  def index
    @events = upcoming_events
    @users = location_users

    if city?
      load_nearby_data
      load_nearby_events

      nearby_event_ids = (@nearby_events || []).map { |nearby| nearby[:event].id }
      exclude_ids = @events.map(&:id) + nearby_event_ids
      @country_events = country_upcoming_events(exclude_ids: exclude_ids)

      if @country_events.empty? && @continent.present?
        @continent_events = continent_upcoming_events(exclude_country_codes: [@city.country_code])
      end

      all_events_for_map = @events.geocoded.to_a
      all_events_for_map += (@nearby_events || []).map { |n| n[:event] }.select(&:geocoded?)
      all_events_for_map += @country_events.geocoded.to_a
      all_events_for_map += (@continent_events || []).to_a.select(&:geocoded?)

      @event_map_markers = event_map_markers(all_events_for_map)
    else
      @event_map_markers = event_map_markers(@events.geocoded)
    end

    @geo_layers = build_sidebar_geo_layers(@events)

    render_location_view("upcoming")
  end

  private

  def filter_events_by_time(events)
    events.select(&:upcoming?)
  end

  def redirect_path_helper
    :city_upcoming_index_path
  end
end
