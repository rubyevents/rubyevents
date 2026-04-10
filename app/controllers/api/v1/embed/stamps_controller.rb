# frozen_string_literal: true

module Api
  module V1
    module Embed
      class StampsController < BaseController
        def show
          user = User.find_by_slug_or_alias(params[:slug])
          user ||= User.find_by_github_handle(params[:slug])
          raise ActiveRecord::RecordNotFound, "User not found" unless user

          stamps = Stamp.for_user(user)

          render json: {
            user: {
              name: user.name,
              slug: user.slug,
              url: build_url("/profiles/#{user.slug}")
            },
            stamps: stamps.map { |stamp| stamp_json(stamp) },
            count: stamps.size,
            grouped: grouped_stamps(stamps)
          }
        end

        private

        def stamp_json(stamp)
          {
            code: stamp.code,
            name: stamp.name,
            image_url: stamp_image_url(stamp),
            has_country: stamp.has_country?,
            has_event: stamp.has_event?,
            country: if stamp.has_country? && stamp.country
                       {
                         name: stamp.country.respond_to?(:name) ? stamp.country.name : stamp.country.to_s,
                         code: stamp.code
                       }
                     end,
            event: (stamp.has_event? && stamp.event) ? {
              name: stamp.event.name,
              slug: stamp.event.slug
            } : nil
          }
        end

        def grouped_stamps(stamps)
          country_stamps = stamps.select(&:has_country?)
          event_stamps = stamps.select(&:has_event?)
          achievement_stamps = stamps.reject { |s| s.has_country? || s.has_event? }

          {
            countries: country_stamps.map { |s| stamp_json(s) },
            events: event_stamps.map { |s| stamp_json(s) },
            achievements: achievement_stamps.map { |s| stamp_json(s) }
          }
        end

        def stamp_image_url(stamp)
          return nil unless stamp.file_path.present?

          if stamp.file_path.include?("/")
            Router.image_path(stamp.file_path, host: request.base_url)
          else
            Router.image_path("stamps/#{stamp.file_path}", host: request.base_url)
          end
        rescue
          nil
        end
      end
    end
  end
end
