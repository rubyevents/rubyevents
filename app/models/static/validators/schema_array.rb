# frozen_string_literal: true

module Static
  module Validators
    class SchemaArray
      def initialize(file_path:, schema:)
        @file_path = file_path
        @schema = schema
      end

      PATTERNS = [
        "**/cfp.yml",
        "**/featured_cities.yml",
        "**/involvements.yml",
        "**/speakers.yml",
        "**/sponsors.yml",
        "**/transcripts.yml",
        "**/videos.yml"
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

      # Returns a flat array of error hashes, one per validation failure:
      #   { "error" => "...", "data_pointer" => "/0/field", "item_label" => "..." }
      def validate
        return [] unless applicable?
        schemer = build_schemer
        data = YAML.load_file(@file_path)
        errors = []

        Array(data).each_with_index do |item, index|
          schemer.validate(item).each do |error|
            error = Static::Validators::Error.new(
              error["error"],
              file_path: @file_path,
              line: 1
            )
            errors << error
          end
        end

        errors
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
