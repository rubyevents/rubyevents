# frozen_string_literal: true

module Static
  module Validators
    class TalkLanguage
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

        nodes = document.root.each.flat_map do |video|
          [video] + Array(video["talks"]&.each&.to_a)
        end

        return [] if nodes.none? { |node| node.value_at("language").present? }

        missing_language = nodes.reject { |node| node["talks"] || node.value_at("language").present? }

        missing_language.map do |node|
          location = node["id"]&.location

          Static::Validators::Error.new(
            %(Other talks in this file already set an explicit "language", so please add one to "#{node.value_at("id")}" as well, e.g. `language: "English"`. That way no talk is left guessing its language.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end
    end
  end
end
