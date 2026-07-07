# frozen_string_literal: true

module Static
  module Validators
    class SchemaArray
      PATH_TO_SCHEMA = {
        "**/cfp.yml" => CFPSchema,
        "**/featured_cities.yml" => FeaturedCitySchema,
        "**/involvements.yml" => InvolvementSchema,
        "**/speakers.yml" => SpeakerSchema,
        "**/sponsors.yml" => SponsorsSchema,
        "**/transcripts.yml" => TranscriptSchema,
        "**/videos.yml" => VideoSchema
      }.freeze

      def initialize(file_path:)
        @file_path = file_path
        @schema = PATH_TO_SCHEMA.find { |pattern, _| File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME) }&.last
      end

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

        document = Yerba.parse_file(@file_path)

        document.validate(json_schema, selector: "[]").map do |error|
          Static::Validators::Error.new(
            error["message"],
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
