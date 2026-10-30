# frozen_string_literal: true

module Hotwire::Native::V1
  class LiveSchedulesController < ApplicationController
    skip_before_action :authenticate_user!

    def show
      event = Event.find_by(slug: params[:event_slug])
      return head(:not_found) unless event

      sessions = event.schedule.exist? ? event.schedule.sessions : []

      render json: {
        event: {
          name: event.name,
          slug: event.slug,
          avatar_url: (Router.image_path(event.avatar_image_path) if event.avatar_image_path.present?),
          featured_background: event.static_metadata.featured_background,
          featured_color: event.static_metadata.featured_color
        },
        time_zone: event.static_metadata.time_zone&.name,
        sessions: sessions.map { |session| session_json(session) }
      }
    end

    private

    def session_json(session)
      {
        start_at: session[:start_at].iso8601,
        end_at: session[:end_at].iso8601,
        date: session[:start_at].strftime("%Y-%m-%d"),
        talks: session[:talks].map { |talk| talk_json(talk) }
      }
    end

    def talk_json(talk)
      {
        title: talk[:title],
        speakers: talk[:speakers] || [],
        speaker_avatars: talk[:speaker_avatars] || [],
        track: talk[:track],
        track_color: talk[:track_color]
      }
    end
  end
end
