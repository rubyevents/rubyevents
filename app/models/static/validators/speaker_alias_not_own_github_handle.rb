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

        Static::Speaker.in_file(@file_path.to_s, document: @document).flat_map do |speaker|
          name = speaker["name"]
          handles = speaker.all_github_handles
          next [] if handles.empty?

          speaker.alias_names.filter_map do |alias_name|
            next unless handles.any? { |handle| alias_name.casecmp?(handle) }

            location = speaker.source_location

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
