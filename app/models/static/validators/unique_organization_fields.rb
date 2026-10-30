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
        errors = []

        [["slug", :alias_slugs], ["name", :alias_names]].each do |field, alias_values|
          owners = organizations.to_h { |organization| [organization[field], organization] }
          alias_owners = Hash.new { |hash, key| hash[key] = [] }
          organizations.each { |organization| organization.public_send(alias_values).each { |value| alias_owners[value] << organization } }

          alias_owners.each do |value, holders|
            if holders.uniq.size > 1
              errors << error("Alias #{field} '#{value}' shared across organizations: #{holders.map(&:slug).uniq.join(", ")}", holders.first)
            end

            if (owner = owners[value]) && holders.any? { |holder| holder != owner }
              errors << error("Alias #{field} '#{value}' on #{holders.map(&:slug).uniq.join(", ")} conflicts with the #{field} of '#{owner.slug}'", holders.first)
            end
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
