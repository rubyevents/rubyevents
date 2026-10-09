# frozen_string_literal: true

module Yerba
  module Record
    module Criteria
      module_function

      def match?(record, criteria)
        criteria.all? { |key, expected| value_matches?(record[key.to_s], expected) }
      end

      def value_matches?(value, expected)
        case expected
        when Array, Set then expected.include?(value)
        when Range then expected.cover?(value)
        else value == expected
        end
      end

      def plain?(criteria)
        criteria.values.none? { |expected| expected.is_a?(Array) || expected.is_a?(Set) || expected.is_a?(Range) }
      end
    end
  end
end
