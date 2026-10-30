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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        mismatched_slugs.map do |sponsor, expected|
          slug = sponsor["slug"].to_s
          name = sponsor["name"].to_s
          location = sponsor.source_location("slug") || sponsor.source_location("name")

          Static::Validators::Error.new(
            %(slug "#{slug}" does not match the parameterized name "#{expected}" for sponsor "#{name}". Run `bin/rails validate:fix` to update it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        return unless applicable?

        changes = mismatched_slugs
        return if changes.empty?

        changes.each { |sponsor, expected| sponsor["slug"] = expected }
        changes.first.first.save!

        {changed: changes.size, file_path: @file_path}
      end

      private

      def sponsors
        @sponsors ||= Static::Sponsor.in_file(@file_path.to_s, document: @document).flat_map do |record|
          record.tiers.flat_map { |tier| tier.sponsors.to_a }
        end
      end

      def mismatched_slugs
        return [] unless applicable?

        sponsors.filter_map do |sponsor|
          name = sponsor["name"].to_s
          expected = name.parameterize

          next if name.blank? || expected.blank? || sponsor["slug"].to_s == expected

          [sponsor, expected]
        end
      end
    end
  end
end
