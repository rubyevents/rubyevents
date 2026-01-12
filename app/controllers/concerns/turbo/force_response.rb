# frozen_string_literal: true

module Turbo
  module ForceResponse
    extend ActiveSupport::Concern

    class_methods do
      def force_frame_response(options = {})
        before_action :force_frame_response, **options
      end

      def force_stream_response(options = {})
        before_action :force_stream_response, **options
      end
    end

    def force_frame_response
      return if turbo_frame_request?

      redirect_back(fallback_location: root_path)
    end

    def force_stream_response
      return if request.format.turbo_stream?

      redirect_back(fallback_location: root_path)
    end
  end
end
