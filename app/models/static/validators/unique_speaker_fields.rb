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

        slug_duplicates = speakers.duplicate_slugs
        slug_duplicates.each do |slug, count|
          errors << Static::Validators::Error.new(
            "Duplicate slug: #{slug} (#{count} occurrences)",
            file_path: @file_path,
            line: 1
          )
        end

        github_duplicates = speakers.duplicate_githubs
        github_duplicates.each do |github, count|
          errors << Static::Validators::Error.new(
            "Duplicate GitHub handle: #{github} (#{count} occurrences)",
            file_path: @file_path,
            line: 1
          )
        end

        errors
      end
    end
  end
end
