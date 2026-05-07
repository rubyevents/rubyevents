# frozen_string_literal: true

module Static
  module Validators
    class Schema
      def initialize(file_path:, schema:)
        @file_path = file_path
        @schema = schema
      end

      PATTERNS = [
        "data/*/*/event.yml",
        "data/*/*/venue.yml",
        "data/*/*/schedule.yml",
        "data/*/series.yml"
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
