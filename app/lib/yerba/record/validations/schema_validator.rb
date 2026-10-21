# frozen_string_literal: true

module Yerba
  module Record
    module Validations
      # Validates the record's attributes against its JSON schema. Registered by `schema`.
      #
      class SchemaValidator < ActiveModel::Validator
        def validate(record)
          schema = record.class.schema
          return unless schema

          Yerba::Document.from(record.to_h).validate(schema.json_schema).each do |error|
            record.errors.add(:base, [error["message"], error["path"].presence].compact.join(" at "))
          end
        end
      end
    end
  end
end
