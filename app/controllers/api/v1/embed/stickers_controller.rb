# frozen_string_literal: true

module Api
  module V1
    module Embed
      class StickersController < BaseController
        def show
          user = User.find_by_slug_or_alias(params[:slug])
          user ||= User.find_by_github_handle(params[:slug])
          raise ActiveRecord::RecordNotFound, "User not found" unless user

          events = user.participated_events.includes(:series).select(&:sticker?)

          stickers = events.flat_map { |event|
            Sticker.for_event(event).map { |sticker|
              {
                code: sticker.code,
                name: sticker.name,
                image_url: sticker_image_url(sticker),
                event: event ? {
                  name: event.name,
                  slug: event.slug
                } : nil
              }
            }
          }.uniq { |s| s[:code] }

          render json: {
            user: {
              name: user.name,
              slug: user.slug,
              url: build_url("/profiles/#{user.slug}")
            },
            stickers: stickers,
            count: stickers.size
          }
        end

        private

        def sticker_image_url(sticker)
          return nil unless sticker.file_path.present?

          Router.image_path(sticker.file_path, host: request.base_url)
        rescue
          nil
        end
      end
    end
  end
end
