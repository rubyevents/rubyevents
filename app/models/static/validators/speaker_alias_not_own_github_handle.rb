# frozen_string_literal: true

module Static
  module Validators
    class SpeakerAliasNotOwnGitHubHandle
      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      PATTERNS = [
        "**/speakers.yml"
      ].freeze

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

        @document ||= Yerba.parse_file(@file_path)

        names = @document.value_at("[].name")
        githubs = @document.value_at("[].github")
        aliases = @document.value_at("[].aliases")

        names.zip(githubs, aliases).flat_map do |name, github, speaker_aliases|
          next [] if github.blank?

          Array(speaker_aliases).filter_map do |alias_entry|
            next unless alias_entry.is_a?(Hash)

            alias_name = alias_entry["name"]
            next unless alias_name&.casecmp?(github)

            location = @document.find_by(name: name)&.location

            Static::Validators::Error.new(
              %(Alias "#{alias_name}" on "#{name}" is redundant, it's already the GitHub handle and GitHub handles act as aliases.),
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end
      end
    end
  end
end
