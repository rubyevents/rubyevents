# frozen_string_literal: true

module Static
  module Validators
    class SchemaArray
      def initialize(file_path:)
        @file_path = file_path
        @schema = PATH_TO_SCHEMA.find { |pattern, _| File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME) }&.last
      end

      PATH_TO_SCHEMA = {
        "**/cfp.yml" => CFPSchema,
        "**/featured_cities.yml" => FeaturedCitySchema,
        "**/involvements.yml" => InvolvementSchema,
        "**/speakers.yml" => SpeakerSchema,
        "**/sponsors.yml" => SponsorsSchema,
        "**/transcripts.yml" => TranscriptSchema,
        "**/videos.yml" => VideoSchema
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
