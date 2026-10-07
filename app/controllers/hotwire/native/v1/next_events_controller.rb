# frozen_string_literal: true

module Hotwire::Native::V1
  class NextEventsController < ApplicationController
    skip_before_action :authenticate_user!

    def show
      events = Event.upcoming.first(6)
      return render(json: {event: nil, upcoming: []}) if events.empty?

      event = events.first
      keynote_speakers = event.keynote_speakers.presence || event.speakers

      render json: {
        event: {
          name: event.name,
          slug: event.slug,
          location: event.location,
          start_date: event.start_date&.to_s,
          start_at: local_iso(event, event.start_date),
          end_at: local_iso(event, event.end_date),
          days_until: days_until(event),
          featured_background: event.static_metadata.featured_background,
          featured_color: event.static_metadata.featured_color,
          banner_background: event.static_metadata.banner_background,
          featured_url: Router.image_path(event.featured_image_path, host: host),
          keynote_avatars: keynote_speakers.first(3).map(&:avatar_url).compact,
          speakers_count: event.speakers.count,
          participants_count: event.participants.count
        },
        upcoming: events.map { |upcoming_event| upcoming_json(upcoming_event) }
      }
    end

    private

    def host
      @host ||= "#{request.protocol}#{request.host}:#{request.port}"
    end

    def local_iso(event, date)
      return nil unless date

      zone = event.static_metadata.time_zone
      zone = ActiveSupport::TimeZone["UTC"] unless zone.is_a?(ActiveSupport::TimeZone)
      zone.local(date.year, date.month, date.day, 9).iso8601
    end

    def days_until(event)
      event.start_date ? (event.start_date - Date.today).to_i : nil
    end

    def upcoming_json(event)
      {
        name: event.name,
        slug: event.slug,
        start_at: local_iso(event, event.start_date),
        days_until: days_until(event),
        featured_background: event.static_metadata.featured_background,
        featured_color: event.static_metadata.featured_color,
        avatar_url: (Router.image_path(event.avatar_image_path, host: host) if event.avatar_image_path.present?)
      }
    end
  end
end
