# frozen_string_literal: true

module Static
  module Validators
    class SlugMatchesName
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
        name_slug_pairs = @document.pluck(:name).zip(@document.pluck(:slug))
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
        name_slug_pairs.filter_map do |name, slug|
          expected_slug = name.parameterize
          next if slug == expected_slug
          next if expected_slug.empty?
          location = block.call(name)&.location
          Static::Validators::Error.new(
            "Slug must be the name parameterized, expected: #{name.to_s.parameterize}",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end
    end
  end
end
