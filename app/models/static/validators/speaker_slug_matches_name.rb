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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        errors = []

        @document ||= Yerba.parse_file(@file_path)
        name_slug_pairs = @document.pluck(:name).zip(@document.pluck(:slug), @document.pluck(:github))
        errors.concat(find_errors_for_name_slug_pairs(name_slug_pairs) do |name|
          @document.find_by(name: name)&.[]("slug")
        end)

        alias_name_slug_pairs = @document.value_at("[].aliases[].name").compact
          .zip(@document.value_at("[].aliases[].slug").compact)
        errors.concat(find_errors_for_name_slug_pairs(alias_name_slug_pairs) do |name|
          @document.find_by(aliases: {name: name})&.[]("aliases")
            &.find_by(name: name)&.[]("slug")
        end)
        errors
      end

      private

      def find_errors_for_name_slug_pairs(name_slug_pairs, &block)
        name_slug_pairs.filter_map do |name, slug, github|
          expected_slug = name.parameterize
          next if slug == expected_slug

          entry = block.call(name)

          if expected_slug.empty?
            next if github.blank?
            expected_slug = github.to_s.parameterize
            next if slug == expected_slug
            Static::Validators::Error.new(
              "Name cannot be parameterized. Slug must be the GitHub handle, expected: #{expected_slug}.",
              file_path: @file_path,
              line: entry&.location&.start_line || 1,
              end_line: entry&.location&.end_line
            )
          else
            Static::Validators::Error.new(
              "Slug must be the name parameterized, expected: #{expected_slug}",
              file_path: @file_path,
              line: entry&.location&.start_line || 1,
              end_line: entry&.location&.end_line
            )
          end
        end
      end
    end
  end
end
