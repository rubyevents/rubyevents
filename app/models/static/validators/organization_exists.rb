# frozen_string_literal: true

module Static
  module Validators
    class OrganizationExists < ReferenceExists
      PATTERNS = ["**/sponsors.yml", "**/involvements.yml"].freeze

      def self.model
        Static::Organization
      end

      def self.missing_references(organizations)
        organizations.missing_organization_references
      end

      def self.add_missing
        Static::Organization.add_missing_organizations
      end

      def self.message(reference)
        %(Organization "#{reference.value}" not found in data/organizations.yml)
      end
    end
  end
end
