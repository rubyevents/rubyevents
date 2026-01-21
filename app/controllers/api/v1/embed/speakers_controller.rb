# frozen_string_literal: true

module Api
  module V1
    module Embed
      class SpeakersController < BaseController
        def index
          slugs = User.with_talks
            .order(talks_count: :desc)
            .limit(params[:limit]&.to_i || 20)
            .pluck(:slug)

          render json: { slugs: slugs }
        end

        def show
          speaker = User.includes(:talks).find_by_slug_or_alias(params[:slug])
          speaker = User.includes(:talks).find_by_github_handle(params[:slug]) unless speaker.present?

          unless speaker.present?
            return render json: {error: "Not found"}, status: :not_found
          end

          render json: {
            name: speaker.name,
            slug: speaker.slug,
            bio: speaker.bio,
            avatar_url: avatar_url(speaker),
            url: Router.speaker_url(speaker, host: request.base_url),
            twitter: speaker.twitter,
            github: speaker.github_handle,
            website: speaker.website,
            talks_count: speaker.talks_count,
            events_count: speaker.events.distinct.count,
            talks: speaker.talks.includes(:event).order(date: :desc).limit(10).map { |talk|
              {
                title: talk.title,
                slug: talk.slug,
                thumbnail_url: full_url(talk.thumbnail_sm),
                event_name: talk.event&.name,
                date: talk.date&.iso8601
              }
            },
            events: speaker.events.distinct.order(start_date: :desc).limit(10).map { |event|
              {
                name: event.name,
                slug: event.slug,
                date: event.start_date&.iso8601,
                location: event.location,
                avatar_url: event_avatar_url(event),
                featured_background: event.static_metadata&.featured_background
              }
            }
          }
        end
      end
    end
  end
end
