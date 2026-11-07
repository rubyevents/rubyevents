# frozen_string_literal: true

module Static
  module Validators
    # Sponsors and involvements name an organization by its current slug. A former slug, kept in the organization's
    # `aliases`, still resolves, but files should be updated; `bin/rails validate:fix` does that. An export that writes
    # these files learns about the new slug from the error.
    class OrganizationAliasReference
      PATTERNS = ["**/sponsors.yml", "**/involvements.yml"].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        return [] unless applicable?

        alias_references.map do |reference, slug|
          Static::Validators::Error.new(
            %(Organization slug "#{reference.value}" is an alias of "#{slug}"; use "#{slug}" (bin/rails validate:fix updates it)),
            file_path: @file_path,
            line: reference.line || 1
          )
        end
      end

      def fix
        changes = alias_references
        return if changes.empty?

        changes.each { |reference, slug| document.set(reference.full_selector, slug) }
        document.save!(apply: true)
        self.class.reset!

        {changed: changes.size, file_path: @file_path}
      end

      # [reference, current slug] for every reference to an alias slug, across all sponsors and involvements files
      def self.all_alias_references
        @all_alias_references ||= begin
          organizations = Static::Organization.in_file(Static::Organization.file_path)

          organizations.all_organization_references.filter_map do |reference|
            organization = organizations.find_by(slug: reference.value)
            [reference, organization["slug"]] if organization && organization["slug"] != reference.value
          end
        end
      end

      def self.warmup
        all_alias_references
      end

      def self.reset!
        @all_alias_references = nil
        [Static::Sponsor, Static::SeriesSponsor, Static::Involvement, Static::SeriesInvolvement].each(&:unload!)
      end

      private

      def alias_references
        self.class.all_alias_references.select { |reference, _| reference.file_path.to_s.sub("#{Rails.root}/", "") == @file_path }
      end

      def document
        @document ||= Yerba.parse_file(@file_path.to_s) # rubocop:disable RubyEvents/PreferStaticModels
      end
    end
  end
end
