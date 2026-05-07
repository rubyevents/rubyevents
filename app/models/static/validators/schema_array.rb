# frozen_string_literal: true

module Static
  module Validators
    class SchemaArray
      Error = Struct.new(:error, :file_path, :line, :data_pointer, :item_label)

      def initialize(file_path:, schema:)
        @file_path = file_path
        @schema = schema
      end

      def errors
        @errors ||= validate
      end

      # Returns a flat array of error hashes, one per validation failure:
      #   { "error" => "...", "data_pointer" => "/0/field", "item_label" => "..." }
      def validate
        schemer = build_schemer
        data = YAML.load_file(@file_path)
        errors = []

        Array(data).each_with_index do |item, index|
          schemer.validate(item).each do |error|
            error["file_path"] = @file_path
            error["line"] = 1 # YAML.load doesn't provide line numbers, unfortunately
            error["data_pointer"] = "/#{index}#{error["data_pointer"]}"
            error["item_label"] = item["name"] || item["title"] || item["id"] || "index #{index}"
            errors << error
          end
        end

        errors
      end

      private

      def build_schemer
        schema_instance = @schema.is_a?(Class) ? @schema.new : @schema
        schema_json = JSON.parse(schema_instance.to_json_schema[:schema].to_json)
        JSONSchemer.schema(schema_json)
      end
    end
  end
end
