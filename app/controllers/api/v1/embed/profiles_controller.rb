# frozen_string_literal: true

module Api
  module V1
    module Embed
      class ProfilesController < BaseController
        def index
          slugs = User.joins(:event_participations)
            .distinct
            .order(updated_at: :desc)
            .limit(params[:limit]&.to_i || 20)
            .pluck(:slug)

          render json: { slugs: slugs }
        end

        def show
          user = User.find_by_slug_or_alias(params[:slug])
          user ||= User.find_by_github_handle(params[:slug])
          raise ActiveRecord::RecordNotFound, "User not found" unless user

          upcoming_events_scope = user.event_participations
            .includes(:event)
            .joins(:event)
            .where("events.start_date >= ?", Date.current)
            .order("events.start_date ASC")

          upcoming_events = upcoming_events_scope.limit(10)

          render json: {
            name: user.name,
            slug: user.slug,
            bio: user.bio,
            avatar_url: avatar_url(user),
            url: Router.profile_url(user, host: request.base_url),
            location: user.location,
            twitter: user.twitter,
            github: user.github_handle,
            website: user.website,
            upcoming_events_count: upcoming_events_scope.count,
            upcoming_events: upcoming_events.map { |participation|
              {
                name: participation.event.name,
                slug: participation.event.slug,
                date: participation.event.start_date&.iso8601,
                end_date: participation.event.end_date&.iso8601,
                location: participation.event.location,
                attended_as: participation.attended_as,
                avatar_url: participation.event.avatar_url,
                featured_background: participation.event.static_metadata&.featured_background
              }
            }
          }
        end
      end
    end
  end
end
