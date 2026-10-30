# frozen_string_literal: true

module Static
  module Validators
    # Slugs and names in data/organizations.yml are unique, across entries and their aliases.
    class UniqueOrganizationFields
      PATTERNS = ["**/organizations.yml"].freeze

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

        organizations = Static::Organization.in_file(@file_path, document: @document)
        errors = []

        %w[slug name].each do |field|
          organizations.duplicates(field).each do |value, count|
            errors << error("Duplicate #{field}: #{value} (#{count} occurrences)", organizations.find_by(field.to_sym => value))
          end
        end

        errors + validate_aliases(organizations)
      end

      private

      def validate_aliases(organizations)
        slug_owners = organizations.to_h { |organization| [organization["slug"], organization] }
        name_owners = organizations.to_h { |organization| [organization["name"], organization] }
        alias_slug_owners = Hash.new { |hash, key| hash[key] = [] }
        alias_name_owners = Hash.new { |hash, key| hash[key] = [] }

        organizations.each do |organization|
          organization.alias_slugs.each { |slug| alias_slug_owners[slug] << organization }
          organization.alias_names.each { |name| alias_name_owners[name] << organization }
        end

        errors = []

        alias_slug_owners.each do |slug, owners|
          if owners.uniq.size > 1
            errors << error("Alias slug '#{slug}' shared across organizations: #{owners.map(&:slug).uniq.join(", ")}", owners.first)
          end

          if (owner = slug_owners[slug]) && owners.any? { |candidate| candidate != owner }
            errors << error("Alias slug '#{slug}' on #{owners.map(&:slug).uniq.join(", ")} conflicts with the slug of '#{owner.slug}'", owners.first)
          end
        end

        alias_name_owners.each do |name, owners|
          if owners.uniq.size > 1
            errors << error("Alias name '#{name}' shared across organizations: #{owners.map(&:slug).uniq.join(", ")}", owners.first)
          end

          if (owner = name_owners[name]) && owners.any? { |candidate| candidate != owner }
            errors << error("Alias name '#{name}' on #{owners.map(&:slug).uniq.join(", ")} conflicts with the name of '#{owner.slug}'", owners.first)
          end
        end

        errors
      end

      def error(message, organization)
        location = organization&.source_location

        Static::Validators::Error.new(
          message,
          file_path: @file_path,
          line: location&.start_line || 1,
          end_line: location&.end_line
        )
      end
    end
  end
end
