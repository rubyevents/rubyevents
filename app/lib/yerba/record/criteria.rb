# frozen_string_literal: true

module Yerba
  module Record
    # Matches records against `where`/`find_by` criteria, like ActiveRecord:
    #
    #   where(kind: "keynote")                  # stored value
    #   where(kind: %w[keynote panel])          # Array, Set or Range: included in it
    #   where(updated_at: Date.today.all_month) # Date Range: a Time is compared by its date
    #   where(event_slug: "rubyconf-2024")      # not stored: the record's method of that name
    #   where(event: {slug: "rubyconf-2024"})   # Hash: the associated record matches the nested criteria
    #   where(commit: {pr_number: 1234})        # Hash on a plain object: its methods of those names
    #
    module Criteria
      module_function

      def match?(record, criteria)
        criteria.all? { |key, expected| value_matches?(value_for(record, key), expected) }
      end

      def value_matches?(value, expected)
        case expected
        when Hash
          !value.nil? && match?(value, expected)
        when Array, Set
          expected.include?(value)
        when Range
          expected.cover?((value.is_a?(Time) && date_range?(expected)) ? value.to_date : value)
        else
          value == expected
        end
      end

      def date_range?(range)
        bounds = [range.begin, range.end].compact

        bounds.any? && bounds.all? { |bound| bound.instance_of?(Date) }
      end

      def value_for(record, key)
        key = key.to_s

        return record.public_send(key) unless record.respond_to?(:key?)

        if !record.key?(key) && record.respond_to?(key)
          record.public_send(key)
        else
          record[key]
        end
      end

      def plain?(criteria)
        criteria.values.none? { |expected| expected.is_a?(Array) || expected.is_a?(Set) || expected.is_a?(Range) || expected.is_a?(Hash) }
      end
    end
  end
end
