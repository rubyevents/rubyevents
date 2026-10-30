# frozen_string_literal: true

module Static
  module Validators
    class TalkShortKind
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      SHORT_DURATION_THRESHOLD = 10.minutes.to_i

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        videos_file.pairs.flat_map do |video, nested|
          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      private

      def videos_file
        @videos_file ||= Static::Talk.in_file(@file_path, document: @document)
      end

      def talk_errors(node)
        return [] unless node["kind"].to_s.strip.empty?

        duration = CueDuration.duration_in_seconds(node)
        return [] if duration.nil?
        return [] unless duration < SHORT_DURATION_THRESHOLD

        formatted = Duration.seconds_to_formatted_duration(duration, raise: false)
        location = node.source_location("start_cue") || node.source_location("title")

        message = "is only #{formatted} long (under 10 minutes) but has no explicit kind. Short segments are usually not regular talks. Add a `kind` (#{::Talk.kinds.keys}) to classify it, or set `kind: \"talk\"` if it really is a short talk."

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
