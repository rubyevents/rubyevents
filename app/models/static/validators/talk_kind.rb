# frozen_string_literal: true

module Static
  module Validators
    class TalkKind
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

      DEFAULT_KIND = "talk"

      def short?(node)
        duration = CueDuration.duration_in_seconds(node)
        duration && duration < TalkShortKind::SHORT_DURATION_THRESHOLD
      end

      def talk_errors(node)
        kind = node.value_at("kind").to_s.strip
        inferred = Talk::Kind.from_title(node.value_at("title")).to_s

        if kind.empty?
          return [] if inferred == DEFAULT_KIND

          location = node["title"]&.location
          message = "kind is inferred as \"#{inferred}\" from the title but is not set explicitly. Add `kind: \"#{inferred}\"` to the entry if this is a \"#{inferred}\". Otherwise you can explicitly set `kind: \"talk\"` if the tite classifiier didn't get it right."
        elsif kind == DEFAULT_KIND && inferred == DEFAULT_KIND
          return [] if short?(node)

          location = node["kind"]&.location

          message = "kind: \"#{DEFAULT_KIND}\" is redundant because the title already classifies as \"#{DEFAULT_KIND}\". Remove it (only keep an explicit \"#{DEFAULT_KIND}\" to override a non-default classification)."
        else
          return []
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
