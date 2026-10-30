# frozen_string_literal: true

module Static
  module Validators
    # Every organization slug in sponsors.yml and involvements.yml must be an entry (or an alias) in data/organizations.yml.
    class OrganizationExists
      PATTERNS = ["**/sponsors.yml", "**/involvements.yml"].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path.to_s.sub("#{Rails.root}/", "")
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        return [] unless applicable?

        self.class.errors.select { |error| error.file_path == @file_path }
      end

      def fix
        return if errors.empty?

        added = Static::Organization.add_missing_organizations
        Static::Organization.save!
        self.class.reset!

        {changed: added.size, file_path: @file_path}
      end

      def self.errors
        @errors ||= Static::Organization.in_file(Static::Organization.file_path).missing_organization_references.map do |reference|
          Static::Validators::Error.new(
            %(Organization "#{reference.value}" not found in data/organizations.yml),
            file_path: reference.file_path || "",
            line: reference.line || 1
          )
        end
      end

      def self.warmup
        errors
      end

      def self.reset!
        @errors = nil
      end
    end
  end
end
