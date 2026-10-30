# frozen_string_literal: true

module Api
  module V1
    module Embed
      class EventsController < BaseController
        def index
          events = Event.includes(:series)

          events = case params[:filter]
          when "upcoming"
            events.upcoming.order(start_date: :asc)
          when "past"
            events.past.order(start_date: :desc)
          else
            events.order(start_date: :desc)
          end

          events = events.limit(params[:limit]&.to_i || 20)

          if params[:slugs_only] == "true"
            render json: {slugs: events.pluck(:slug)}
          else
            render json: {
              events: events.map { |event| event_summary_json(event) }
            }
          end
        end

        def show
          event = Event.find_by_slug_or_alias(params[:slug])
          raise ActiveRecord::RecordNotFound, "Event not found" unless event

          keynote_speakers = event.keynote_speakers.limit(20).to_a
          speakers = event.speakers.where.not(id: event.keynote_speakers.select(:id)).limit(20).to_a
          attendees = event.participants.where(event_participations: {role: :attendee}).limit(20).to_a

          render json: {
            name: event.name,
            slug: event.slug,
            description: event.description,
            location: event.location,
            city: event.city,
            country_code: event.country_code,
            start_date: event.start_date&.iso8601,
            end_date: event.end_date&.iso8601,
            kind: event.kind,
            website: event.website,
            url: Router.event_url(event, host: request.base_url),
            avatar_url: event_avatar_url(event),
            banner_url: event_banner_url(event),
            featured_background: event.static_metadata&.featured_background,
            featured_color: event.static_metadata&.featured_color,
            talks_count: event.talks_count,
            speakers_count: event.speakers.count,
            series: event.series ? {
              name: event.series.name,
              slug: event.series.slug
            } : nil,
            participants: {
              keynote_speakers: keynote_speakers.map { |user| participant_json(user) },
              speakers: speakers.map { |user| participant_json(user) },
              attendees: attendees.map { |user| participant_json(user) }
            },
            counts: {
              keynote_speakers: event.keynote_speakers.count,
              speakers: event.speakers.where.not(id: event.keynote_speakers.select(:id)).count,
              attendees: event.participants.where(event_participations: {role: :attendee}).count,
              total: event.going_participants.count
            }
          }
        end

        def participants
          event = Event.find_by_slug_or_alias(params[:slug])
          raise ActiveRecord::RecordNotFound, "Event not found" unless event

          keynote_speakers = event.keynote_speakers.to_a
          speakers = event.speakers.where.not(id: event.keynote_speakers.select(:id)).to_a
          attendees = event.participants.where(event_participations: {role: :attendee}).to_a

          render json: {
            event: {
              name: event.name,
              slug: event.slug,
              url: build_url("/events/#{event.slug}")
            },
            participants: {
              keynote_speakers: keynote_speakers.map { |user| participant_json(user) },
              speakers: speakers.map { |user| participant_json(user) },
              attendees: attendees.map { |user| participant_json(user) }
            },
            counts: {
              keynote_speakers: keynote_speakers.size,
              speakers: speakers.size,
              attendees: attendees.size,
              total: keynote_speakers.size + speakers.size + attendees.size
            }
          }
        end

        private

        def participant_json(user)
          {
            name: user.name,
            slug: user.slug,
            avatar_url: avatar_url(user)
          }
        end

        def event_summary_json(event)
          {
            name: event.name,
            slug: event.slug,
            location: event.location,
            start_date: event.start_date&.iso8601,
            end_date: event.end_date&.iso8601,
            url: Router.event_url(event, host: request.base_url),
            avatar_url: event_avatar_url(event),
            banner_url: event_banner_url(event),
            featured_background: event.static_metadata&.featured_background,
            featured_color: event.static_metadata&.featured_color
          }
        end
      end
    end
  end
end
