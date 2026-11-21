# frozen_string_literal: true

module Static
  # A meetup series is named after the group, without "Meetup": its meetups are titled "<name> Meetup <Month> <Year>".
  # A meetup series nested under a parent of the same name keeps "Meetup" to tell the two apart: "SF Ruby Meetup" under "SF Ruby".
  #
  class MeetupSeriesNameValidator < ActiveModel::EachValidator
    SUFFIX = /\s+Meetup\z/i

    def validate_each(series, attribute, value)
      expected = expected_name(series)
      return unless expected

      series.errors.add(attribute, %("#{value}" ends in "Meetup", expected "#{expected}". The series is named after the group, and its meetups are titled "<name> Meetup <Month> <Year>". Run `bin/rails validate:fix` to rename it.))
    end

    def fix(series)
      expected = expected_name(series)
      return 0 unless expected

      series["name"] = expected

      1
    end

    private

    def expected_name(series)
      return unless series["kind"] == "meetup" && series["name"].to_s.match?(SUFFIX)

      name = series["name"].to_s.sub(SUFFIX, "")

      name unless series.parent&.[]("name") == name
    end
  end
end
