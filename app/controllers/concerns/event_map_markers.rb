# frozen_string_literal: true

module EventMapMarkers
  extend ActiveSupport::Concern

  private

  def event_map_markers(events = Event.includes(:series).geocoded)
    events
      .group_by(&:to_coordinates)
      .map do |(latitude, longitude), grouped_events|
        {
          latitude: latitude,
          longitude: longitude,
          events: grouped_events
            .sort_by { |e| e.start_date || Time.at(0) }
            .reverse
            .map { |event| event_marker_data(event) }
        }
      end
  end

  def event_marker_data(event)
    {
      name: event.name,
      url: Router.event_path(event),
      avatar: Router.image_path(event.avatar_image_path),
      location: event.location
    }
  end
end
