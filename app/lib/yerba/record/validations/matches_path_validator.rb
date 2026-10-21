# frozen_string_literal: true

module Yerba
  module Record
    module Validations
      # Checks that an attribute matches the folder of the record's path with the same name:
      #
      #   self.path = "data/:series_id/:id/event.yml"
      #   validates :id, matches_path: true
      #
      class MatchesPathValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          expected = record.path_params[(options[:segment] || attribute).to_sym]
          return if expected.nil? || value.to_s == expected.to_s

          message = value.blank? ? %(is required and must match the folder name "#{expected}") : %("#{value}" does not match the folder name "#{expected}")

          record.errors.add(attribute, :path_mismatch, **options.except(:segment, :message), message: options[:message] || message)
        end
      end
    end
  end
end
