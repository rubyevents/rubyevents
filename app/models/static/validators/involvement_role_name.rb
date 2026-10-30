# frozen_string_literal: true

module Static
  module Validators
    class InvolvementRoleName
      PATTERNS = ["**/involvements.yml"].freeze

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

        errors = []

        involvements.each do |involvement|
          name = involvement["name"]

          if name.present? && name.singularize != name
            location = involvement.source_location("name")

            errors << Static::Validators::Error.new(
              "'#{name}' should be singular",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end

          if name.blank? && involvement["organisations"].blank?
            location = involvement.source_location

            errors << Static::Validators::Error.new(
              "'#{name || "Involvement"}' must have at least one name or organisation",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end

        errors
      end

      private

      def involvements
        @involvements ||= Static::Involvement.in_file(@file_path.to_s, document: @document)
      end
    end
  end
end
