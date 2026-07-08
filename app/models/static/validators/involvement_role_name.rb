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
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        errors = []

        Array(document).each do |involvement|
          name = involvement["name"]

          if name.present? && name.singularize != name
            errors << Static::Validators::Error.new(
              "'#{name}' should be singular",
              file_path: @file_path,
              line: 1
            )
          end
        end

        errors
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end
    end
  end
end
