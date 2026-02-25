# frozen_string_literal: true

module Api
  module V1
    module Embed
      class TopicsController < BaseController
        def show
          topic = Topic.approved.find_by!(slug: params[:slug])

          talks = topic.talks
            .includes(:event, :users)
            .order(date: :desc)
            .limit(params[:limit]&.to_i || 10)

          render json: {
            name: topic.name,
            slug: topic.slug,
            description: topic.description,
            url: build_url("/topics/#{topic.slug}"),
            talks_count: topic.talks_count || 0,
            talks: talks.map { |talk|
              {
                title: talk.title,
                slug: talk.slug,
                thumbnail_url: full_url(talk.thumbnail_md),
                duration_in_seconds: talk.duration_in_seconds,
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
                  slug: talk.event.slug
                } : nil
              }
            }
          }
        end
      end
    end
  end
end
