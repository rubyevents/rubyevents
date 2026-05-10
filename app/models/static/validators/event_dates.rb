# frozen_string_literal: true

module Static
  module Validators
    class EventDates
      def initialize(file_path:)
        @file_path = file_path
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

        document = Yerba.parse_file(@file_path)
        return [] if document["kind"] == "meetup"

        errors = []

        if document["start_date"].nil? || document["start_date"].to_s.strip.empty?
          location = document["start_date"]&.location
          errors << Static::Validators::Error.new(
            "start_date is required for non-meetup events at /start_date",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        if document["end_date"].nil? || document["end_date"].to_s.strip.empty?
          location = document["end_date"]&.location
          errors << Static::Validators::Error.new(
            "end_date is required for non-meetup events at /end_date",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end
    end
  end
end
