# frozen_string_literal: true

module Yerba
  module Record
    class RecordInvalid < ArgumentError
      attr_reader :record

      def initialize(record)
        @record = record

        super("Validation failed: #{record.blocking_errors.map(&:full_message).join(", ")}")
      end
    end
  end
end
