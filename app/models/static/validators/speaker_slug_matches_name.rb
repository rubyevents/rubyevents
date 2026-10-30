# frozen_string_literal: true

module Static
  module Validators
    class SpeakerSlugMatchesName
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

        speakers = Static::Speaker.in_file(@file_path.to_s, document: @document).to_a

        name_slugs = speakers.map { |speaker| [speaker["name"], speaker["slug"], speaker["github"], speaker.source_location("slug")] }

        alias_slugs = speakers.flat_map do |speaker|
          Array(speaker["aliases"]).each_with_index.map do |alias_entry, index|
            [alias_entry["name"], alias_entry["slug"], nil, speaker.source_location("aliases[#{index}].slug")]
          end
        end

        find_errors_for_name_slugs(name_slugs) + find_errors_for_name_slugs(alias_slugs)
      end

      private

      def find_errors_for_name_slugs(name_slugs)
        name_slugs.filter_map do |name, slug, github, location|
          expected_slug = name.parameterize
          next if slug == expected_slug

          if expected_slug.empty?
            next if github.blank?
            expected_slug = github.to_s.parameterize
            next if slug == expected_slug
            Static::Validators::Error.new(
              "Name cannot be parameterized. Slug must be the GitHub handle, expected: #{expected_slug}.",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          else
            Static::Validators::Error.new(
              "Slug must be the name parameterized, expected: #{expected_slug}",
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
