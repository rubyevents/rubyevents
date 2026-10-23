# frozen_string_literal: true

module Static
  module Validators
    class EventDates
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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?
        return [] if event["kind"] == "meetup"

        errors = []

        if event["start_date"].to_s.strip.empty?
          location = event.source_location("start_date")

          errors << Static::Validators::Error.new(
            "start_date is required for non-meetup events at /start_date",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        if event["end_date"].to_s.strip.empty?
          location = event.source_location("end_date")

          errors << Static::Validators::Error.new(
            "end_date is required for non-meetup events at /end_date",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        %w[start_date end_date].each do |field|
          value = event[field].to_s.strip
          next if value.empty? || valid_date?(value)

          location = event.source_location(field)

          errors << Static::Validators::Error.new(
            %(#{field} "#{value}" is not a date, use YYYY-MM-DD and set `date_precision` to "month" or "year" when the exact date is unknown),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      private

      def valid_date?(value)
        value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(value)
      rescue Date::Error
        false
      end

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end
    end
  end
end
