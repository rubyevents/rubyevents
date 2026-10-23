# frozen_string_literal: true

module Static
  # A talk happens within its event's dates (or from its pre_date), and isn't published before it happened.
  # A `# validator:disable published_at_before_date` comment on the published_at line allows the latter.
  #
  class TalkDatesValidator < ActiveModel::Validator
    IGNORE_PUBLISHED_AT_BEFORE_DATE = "validator:disable published_at_before_date"

    def validate(talk)
      return if ::Talk::SUPPLEMENTARY_KINDS.include?(talk["kind"])

      date = parse_date(talk["date"])
      return unless date

      event = talk.event
      published_at = published_local_date(talk["published_at"], event&.[]("timezone"))

      if published_at && published_at < date && !ignored?(talk, "published_at")
        talk.errors.add(:published_at, "(#{talk["published_at"]}) must not be before the talk date (#{talk["date"]})")
      end

      return unless event

      start_date = [parse_date(event["pre_date"]), parse_date(event["start_date"])].compact.min
      end_date = parse_date(event["end_date"])
      return if start_date.nil? || end_date.nil? || date.between?(start_date, end_date)

      talk.errors.add(:date, "(#{talk["date"]}) must be within the event dates (#{start_date} to #{end_date}). " \
        "If this is a pre-conference activity (e.g. workshops or a pre-party) held before the event, add a pre_date to the event.yml.")
    end

    private

    def ignored?(talk, key)
      line = talk.source_line(key)
      return false unless line && talk.file_path

      lines = Yerba::Record::Validations.cached(self.class, talk.file_path) { File.readlines(talk.file_path) }
      lines[line - 1].to_s.include?(IGNORE_PUBLISHED_AT_BEFORE_DATE)
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    def published_local_date(value, timezone)
      string = value.to_s.strip
      return nil if string.empty?
      return parse_date(string) unless string.include?("T")

      time = Time.parse(string)
      zone = timezone && Time.find_zone(timezone)

      (zone ? time.in_time_zone(zone) : time).to_date
    rescue ArgumentError, TypeError
      nil
    end
  end
end
