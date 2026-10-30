# frozen_string_literal: true

module Static
  module Validators
    # Organization slugs (and alias slugs) are what URLs and references use: lowercase letters, digits, dashes and
    # underscores, as `parameterize` produces them.
    class OrganizationSlugFormat
      PATTERNS = ["**/organizations.yml"].freeze
      SLUG_FORMAT = /\A[a-z0-9]+(?:[-_][a-z0-9]+)*\z/

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
        return [] unless applicable?

        Static::Organization.in_file(@file_path, document: @document).flat_map do |organization|
          checks = [[organization["slug"], organization.source_location("slug")]]
          Array(organization["aliases"]).each_with_index do |entry, index|
            checks << [entry["slug"], organization.source_location("aliases[#{index}].slug")] if entry.is_a?(Hash)
          end

          checks.filter_map do |slug, location|
            next if slug.to_s.match?(SLUG_FORMAT)

            Static::Validators::Error.new(
              %(slug "#{slug}" must consist of lowercase letters, digits, dashes and underscores, like "#{Static::Organization.slug_for(slug)}"),
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
