# frozen_string_literal: true

module Static
  module Validators
    class Schema
      def initialize(file_path:, selector: nil)
        @file_path = file_path
        @schema = ApplicationSchema.schemas.find { |schema| schema.matches?(@file_path) }
        @selector = selector || @schema&.data_file_selector
      end

      def applicable?
        @schema.present? && File.exist?(@file_path)
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        document = Yerba.parse_file(@file_path.to_s)

        document.validate(@schema.json_schema, selector: @selector).map do |error|
          Static::Validators::Error.new(
            message_for(error),
            file_path: @file_path,
            line: error["line"] || 1
          )
        end
      end

      private

      def message_for(error)
        message = [error["message"], error["path"].presence].compact.join(" at ")
        message += %( ("#{error["item_label"]}")) if error["item_label"].present?

        message
      end
    end
  end
end
