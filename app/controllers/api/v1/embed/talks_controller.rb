# frozen_string_literal: true

module Api
  module V1
    module Embed
      class TalksController < BaseController
        def index
          slugs = Talk.watchable
            .order(date: :desc)
            .limit(params[:limit]&.to_i || 20)
            .pluck(:slug)

          render json: { slugs: slugs }
        end

        def show
          talk = Talk.includes(:event, :users).find_by!(slug: params[:slug])

          render json: {
            slug: talk.slug,
            title: talk.title,
            description: talk.description,
            thumbnail_url: full_url(talk.thumbnail_md),
            duration_in_seconds: talk.duration_in_seconds,
            video_provider: talk.video_provider,
            date: talk.date&.iso8601,
            url: build_url("/talks/#{talk.slug}"),
            speakers: talk.users.map { |speaker|
              {
                name: speaker.name,
                slug: speaker.slug,
                avatar_url: avatar_url(speaker)
              }
            },
            event: talk.event ? {
              name: talk.event.name,
              slug: talk.event.slug,
              location: talk.event.location
            } : nil
          }
        end
      end
    end
  end
end
