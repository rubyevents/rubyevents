# frozen_string_literal: true

module Static
  module Validators
    class TalkPublishedAt
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        return [] unless document.root

        document.root.each.flat_map do |video|
          nested = Array(video["talks"]&.each&.to_a)

          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      private

      PROVIDERS_WITHOUT_PUBLISHED_AT = (Talk::UNPUBLISHED_PROVIDERS + ["children", "parent"]).freeze

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def talk_errors(node)
        provider = node.value_at("video_provider")

        return [] unless PROVIDERS_WITHOUT_PUBLISHED_AT.include?(provider)
        return [] if node.value_at("published_at").to_s.strip.empty?

        location = node["published_at"]&.location

        [
          Static::Validators::Error.new(
            "published_at (#{node.value_at("published_at")}) must not be set when video_provider is \"#{provider}\"",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end
    end
  end
end
