# frozen_string_literal: true

module Static
  # A meetup's title is its group, "Meetup" and month: "LRUG Meetup October 2026", with the day when the group meets
  # more than once that month: "bangkok.rb Meetup January 14, 2026". The group is the series' `meetup_name`, or its
  # `name`. A group whose name already says it is a group leaves out "Meetup": "Helsinki Ruby Brigade May 2026".
  # What the organizers call that meetup goes in `subtitle`: "Pubnite", "Ruby Tuesday #12".
  #
  class MeetupTitleValidator < ActiveModel::Validator
    GERMAN_MONTHS = %w[Januar Februar März April Mai Juni Juli August September Oktober November Dezember].freeze
    MONTH_NAMES = (Date::MONTHNAMES.compact + GERMAN_MONTHS).uniq.freeze
    GENERIC_NAMES = ["ruby", "rails", "ruby on rails"].freeze
    GROUP_WORDS = /\b(user ?groups?|users group|usergroup|group|brigade|grupa|workshop|meetup)\b/i

    def self.title_name(series)
      name = series["meetup_name"].presence || series["name"]

      name.match?(GROUP_WORDS) ? name : "#{name} Meetup"
    end

    # Memoized for the event generator, which titles one meetup after another; call reset_meetup_dates! after writing one.
    def self.meetup_dates(series_directory)
      @meetup_dates ||= {}
      @meetup_dates[series_directory] ||= read_meetup_dates(series_directory)
    end

    def self.reset_meetup_dates!
      @meetup_dates = nil
    end

    def self.read_meetup_dates(series_directory)
      Dir.glob(File.join(series_directory, "*", "event.yml")).filter_map do |path|
        Date.parse(File.read(path)[/^start_date: "?(\d{4}-\d{2}-\d{2})/, 1].to_s)
      rescue Date::Error
        nil
      end
    end

    def validate(event)
      expected = expected_title(event)
      return if expected.nil? || event["title"] == expected

      event.errors.add(:title, %("#{event["title"]}" should be "#{expected}", the group, "Meetup" (unless the group's name already says it is a group) and month. What the organizers call this meetup goes in `subtitle`. Run `bin/rails validate:fix` to rename it and keep the old wording as its subtitle.))
    end

    def fix(event)
      expected = expected_title(event)
      return 0 if expected.nil? || event["title"] == expected

      if event["subtitle"].blank?
        subtitle = subtitle_from(event, event["title"].to_s)
        event["subtitle"] = subtitle if subtitle.present?
      end

      event["title"] = expected

      1
    end

    def expected_title(event)
      date = date_of(event)
      return unless event.meetup? && date && event.series

      series_directory = File.dirname(File.expand_path(event.file_path.to_s), 2)
      dates = Yerba::Record::Validations.cached(self.class, series_directory) { self.class.read_meetup_dates(series_directory) }
      same_month = dates.count { |other| other.year == date.year && other.month == date.month }
      month = (same_month > 1) ? "#{Date::MONTHNAMES[date.month]} #{date.day}," : Date::MONTHNAMES[date.month]

      "#{self.class.title_name(event.series)} #{month} #{date.year}"
    end

    private

    def subtitle_from(event, title)
      date = date_of(event)
      months = [Date::MONTHNAMES[date.month], GERMAN_MONTHS[date.month - 1]].uniq.map { |name| Regexp.escape(name) }
      match = title.match(/\A(?<prefix>.*?)[\s\-–:,]*\b(?:#{months.join("|")})(?:\s+\d{1,2},?)?\s+#{date.year}(?<suffix>.*)\z/)

      match ||= title.match(/\A(?<prefix>.*?)[\s\-–:,]*\b(?:#{MONTH_NAMES.join("|")})(?:\s+\d{1,2},?)?\s+\d{4}(?<suffix>.*)\z/)
      return (title unless group_name?(event, title)) unless match

      prefix = match[:prefix].sub(/[\s\-–:,]+\z/, "").sub(/\s+meetup\z/i, "")
      suffix = match[:suffix].sub(/\A[\s\-–:,]+/, "").strip.sub(/\A\((.*)\)\z/, '\1')

      [(prefix unless prefix.empty? || group_name?(event, prefix)), suffix.presence].compact.join(": ").presence
    end

    def date_of(event)
      Date.parse(event["start_date"].to_s)
    rescue Date::Error
      nil
    end

    def group_names(series)
      group_name = series["meetup_name"].presence || series["name"]

      [group_name, series["name"], series["meetup_name"], *Array(series["aliases"])].compact_blank.map { |name| normalize(name) }.uniq
    end

    def group_name?(event, name)
      normalized = normalize(name)
      names = group_names(event.series)
      return true if GENERIC_NAMES.include?(normalized) || names.include?(normalized)

      words = words_of(normalized)
      names.any? { |group| (words - words_of(group)).empty? }
    end

    def words_of(name)
      name.split(/[^[:alnum:].+#]+/).compact_blank.map { |word| word.delete_suffix("s") }
    end

    def normalize(name)
      name.to_s.sub(/\s+meetup\z/i, "").strip.downcase
    end
  end
end
