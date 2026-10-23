# frozen_string_literal: true

module Static
  # With date_precision "month" or "year", the dates must be the last day of that month or year
  #
  class DatePrecisionValidator < ActiveModel::EachValidator
    def validate_each(event, attribute, value)
      expected = expected_date(event, value)
      return unless expected

      event.errors.add(attribute, %((#{value}) must be the last day of the #{event["date_precision"]} (#{expected}) when date_precision is "#{event["date_precision"]}". Run `bin/rails validate:fix` to update it.))
    end

    def fix(event)
      attributes.count do |attribute|
        expected = expected_date(event, event[attribute])
        event[attribute] = expected.iso8601 if expected
      end
    end

    private

    def expected_date(event, value)
      precision = event["date_precision"].to_s
      return unless precision.in?(%w[month year])

      date = Date.parse(value.to_s)
      expected = (precision == "year") ? date.end_of_year : date.end_of_month

      expected unless date == expected
    rescue Date::Error, TypeError
      nil
    end
  end
end
