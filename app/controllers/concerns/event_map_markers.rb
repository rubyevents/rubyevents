# frozen_string_literal: true

module EventMapMarkers
  extend ActiveSupport::Concern

  private

  def event_map_markers(events = Event.includes(:series))
    events
      .select { |event| event.longitude.present? && event.latitude.present? }
      .group_by(&:coordinates)
      .transform_values { |grouped_events| grouped_events.sort_by { |e| event_sort_date(e) }.reverse }
      .map do |(longitude, latitude), grouped_events|
        {
          longitude: longitude,
          latitude: latitude,
          events: grouped_events.map { |event| event_marker_data(event) }
        }
      end
  end

  def event_sort_date(event)
    event.static_metadata&.home_sort_date || Time.at(0)
  end

  def event_marker_data(event)
    {
      name: event.name,
      url: event_url(event),
      avatar: ActionController::Base.helpers.image_path(event.avatar_image_path),
      location: event.static_metadata&.location
    }
  end
end
