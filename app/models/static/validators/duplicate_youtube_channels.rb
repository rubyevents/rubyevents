# frozen_string_literal: true

module Static
  module Validators
    class DuplicateYouTubeChannels
      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      PATTERNS = [
        "**/event.yml"
      ].freeze

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

        event_channels = Array(document.value_at("youtube_channels"))
        return [] if event_channels.empty?

        series_path = File.join(File.dirname(@file_path, 2), "series.yml")
        return [] unless File.exist?(series_path)

        series_document = Yerba.parse_file(series_path)
        series_ids = Array(series_document.value_at("youtube_channels")).map { |c| c["id"] }.to_set
        return [] if series_ids.empty?

        errors = []

        event_channels.each do |channel|
          next unless channel.is_a?(Hash) && series_ids.include?(channel["id"])

          location = document["youtube_channels"]&.location
          errors << Static::Validators::Error.new(
            "youtube_channels contains channel \"#{channel["id"]}\" (#{channel["name"] || "unknown"}) which is already defined in series.yml — remove it from event.yml",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end
    end
  end
end
