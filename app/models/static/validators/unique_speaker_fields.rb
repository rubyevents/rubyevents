# frozen_string_literal: true

module Static
  module Validators
    class UniqueSpeakerFields
      def initialize(file_path:)
        @file_path = file_path
      end

      PATTERNS = [
        "**/speakers.yml"
      ].freeze

      UNIQUE_FIELDS = %w[
        slug
        github
        twitter
        speakerdeck
        mastodon
        bluesky
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

        speakers = Static::SpeakersFile.new(@file_path)
        errors = []

        # TODO: Get location for speaker fields

        UNIQUE_FIELDS.each do |field|
          speakers.duplicates(field).each do |value, count|
            errors << Static::Validators::Error.new(
              "Duplicate #{field}: #{value} (#{count} occurrences)",
              file_path: @file_path,
              line: 1,
              end_line: 1
            )
          end
        end

        errors
      end
    end
  end
end
