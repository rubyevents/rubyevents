# frozen_string_literal: true

module Static
  module Validators
    class SponsorSlug
      PATTERNS = ["**/sponsors.yml"].freeze

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

        sponsors.flat_map do |sponsor|
          name = sponsor.value_at("name").to_s
          slug = sponsor.value_at("slug").to_s
          expected = name.parameterize

          next [] if name.blank? || slug == expected

          location = sponsor["slug"]&.location || sponsor["name"]&.location

          Static::Validators::Error.new(
            %(slug "#{slug}" does not match the parameterized name "#{expected}" for sponsor "#{name}"),
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

      def sponsors
        document["[0].tiers[].sponsors[]"]
      end
    end
  end
end
