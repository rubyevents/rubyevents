# frozen_string_literal: true

module Api
  module V1
    module Embed
      class BaseController < ActionController::API
        before_action :set_cors_headers

        rescue_from ActiveRecord::RecordNotFound, with: :not_found
        rescue_from StandardError, with: :internal_error

        def preflight
          head :ok
        end

        private

        def set_cors_headers
          headers["Access-Control-Allow-Origin"] = "*"
          headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
          headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Origin, X-Requested-With"
          headers["Access-Control-Max-Age"] = "86400"
        end

        def not_found
          render json: {error: "Not found"}, status: :not_found
        end

        def internal_error(exception)
          Rails.logger.error("Embed API Error: #{exception.message}")
          Rails.logger.error(exception.backtrace.first(10).join("\n"))
          render json: {error: "Internal server error"}, status: :internal_server_error
        end

        def build_url(path)
          "#{request.base_url}#{path}"
        end

        def avatar_url(user)
          return nil unless user

          if user.respond_to?(:avatar_url)
            user.avatar_url(size: 200)
          elsif user.github_handle.present?
            "https://avatars.githubusercontent.com/#{user.github_handle}?s=200"
          end
        end

        def full_url(path)
          return path if path.blank? || path.start_with?("http")

          "#{request.base_url}#{path}"
        end

        def event_avatar_url(event)
          return nil unless event&.avatar_image_path

          Router.image_path(event.avatar_image_path, host: request.base_url)
        rescue
          nil
        end

        def event_banner_url(event)
          return nil unless event&.banner_image_path

          Router.image_path(event.banner_image_path, host: request.base_url)
        rescue
          nil
        end
      end
    end
  end
end
