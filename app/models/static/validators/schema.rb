# frozen_string_literal: true

module Static
  module Validators
    class Schema
      def initialize(file_path:)
        @file_path = file_path
        @schema = PATH_TO_SCHEMA.find { |pattern, _| File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME) }&.last
      end

      PATH_TO_SCHEMA = {
        "**/event.yml" => EventSchema,
        "**/schedule.yml" => ScheduleSchema,
        "**/series.yml" => SeriesSchema,
        "**/venue.yml" => VenueSchema
      }.freeze

      def applicable?
        return false unless File.exist?(@file_path)

        PATH_TO_SCHEMA.keys.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        document = Yerba.parse_file(@file_path.to_s)

        document.validate(json_schema).map do |error|
          message = [error["message"], error["path"].presence].compact.join(" at ")

          Static::Validators::Error.new(
            message,
            file_path: @file_path,
            line: error["line"] || 1
          )
        end
      end

      private

      def json_schema
        @schema.json_schema
      end
    end
  end
end
