# frozen_string_literal: true

module Static
  module Validators
    class TalkLanguage
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
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

        return [] unless document.root

        pairs = document.root.each.flat_map do |video|
          [[video, nil]] + Array(video["talks"]&.each&.to_a).map { |talk| [talk, video] }
        end

        with_language = pairs.map(&:first).select { |node| node.value_at("language").present? }
        return [] if with_language.empty?

        missing_language = pairs.select do |node, parent|
          next false if node["talks"] || node.value_at("language").present?

          watchable?(node, parent)
        end.map(&:first)

        missing_language.map do |node|
          location = node["id"]&.location

          Static::Validators::Error.new(
            %(Other talks in this file already set an explicit "language", so please add one to "#{node.value_at("id")}" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way no talk is left guessing its language.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def watchable?(node, parent)
        provider = node.value_at("video_provider")
        provider = parent&.value_at("video_provider") if provider == "parent"

        provider.in?(::Talk::WATCHABLE_PROVIDERS)
      end
    end
  end
end
