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

        data = YAML.load_file(@file_path)
        raw_errors = build_schemer.validate(data).to_a

        raw_errors.map do |e|
          Static::Validators::Error.new(
            "#{e["error"]} at #{e["data_pointer"]}",
            file_path: @file_path,
            line: 1
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
