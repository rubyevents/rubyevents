# frozen_string_literal: true

module Static
  module Validators
    class SpeakersOrTalks
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:)
        @file_path = file_path
      end

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

        document = Yerba.parse_file(@file_path)
        return [] unless document.root

        document.root.each.flat_map do |video|
          nested = Array(video["talks"]&.each&.to_a)

          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      private

      def talk_errors(node)
        has_talks = node.key?("talks")
        has_speakers = node.key?("speakers")

        return [] if has_talks ^ has_speakers

        location = (node["talks"] || node["speakers"] || node["title"])&.location

        message = if has_talks && has_speakers
          "an entry must have either `talks` or `speakers`, but not both."
        else
          "an entry must have either `talks` (a container) or `speakers` (a single talk), but has neither."
        end

        [
          Static::Validators::Error.new(
            message,
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end
    end
  end
end
