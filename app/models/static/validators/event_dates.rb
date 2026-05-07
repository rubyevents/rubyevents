# frozen_string_literal: true

module Static
  module Validators
    class EventDates
      def initialize(file_path:)
        @file_path = file_path
      end

      def applicable?
        return false unless File.exist?(@file_path)
        @file_path.match?(/event\.yml$/)
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        data = YAML.load_file(@file_path)
        return [] if data["kind"] == "meetup"

        errors = []

        if data["start_date"].nil? || data["start_date"].to_s.strip.empty?
          errors << Static::Validators::Error.new(
            "start_date is required for non-meetup events at /start_date",
            file_path: @file_path,
            line: 1
          )
        end

        if data["end_date"].nil? || data["end_date"].to_s.strip.empty?
          errors << Static::Validators::Error.new(
            "end_date is required for non-meetup events at /end_date",
            file_path: @file_path,
            line: 1
          )
        end

        errors
      end
    end
  end
end
