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
        raw_errors = build_schemer.validate(document.to_h).to_a

        raw_errors.map do |e|
          data_pointer = e["data_pointer"].gsub(/\A\//, "").tr("/", ".") || ""
          location = document[data_pointer]&.location
          Static::Validators::Error.new(
            "#{e["error"]} at #{e["data_pointer"]}",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      private

      def build_schemer
        schema_instance = @schema.is_a?(Class) ? @schema.new : @schema
        schema_json = JSON.parse(schema_instance.to_json_schema[:schema].to_json)
        JSONSchemer.schema(schema_json)
      end
    end
  end
end
