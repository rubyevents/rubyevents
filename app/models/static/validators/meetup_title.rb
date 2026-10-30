# frozen_string_literal: true

module Static
  module Validators
    # A meetup's title is its group, "Meetup" and month: "LRUG Meetup October 2026", with the day when the group meets
    # more than once that month: "bangkok.rb Meetup January 14, 2026". The group is the series' `meetup_name`, or its
    # `name`. A group whose name already says it is a group leaves out "Meetup": "Helsinki Ruby Brigade May 2026".
    # What the organizers call that meetup goes in `subtitle`: "Pubnite", "Ruby Tuesday #12".
    #
    class MeetupTitle
      PATTERNS = [
        "**/event.yml"
      ].freeze

      GERMAN_MONTHS = %w[Januar Februar März April Mai Juni Juli August September Oktober November Dezember].freeze
      MONTH_NAMES = (Date::MONTHNAMES.compact + GERMAN_MONTHS).uniq.freeze
      GENERIC_NAMES = ["ruby", "rails", "ruby on rails"].freeze
      GROUP_WORDS = /\b(user ?groups?|users group|usergroup|group|brigade|grupa|workshop|meetup)\b/i

      def self.title_name(series)
        name = series["meetup_name"].presence || series["name"]

        name.match?(GROUP_WORDS) ? name : "#{name} Meetup"
      end

      def self.meetup_dates(series_directory)
        @meetup_dates ||= {}

        @meetup_dates[series_directory] ||= Dir.glob(File.join(series_directory, "*", "event.yml")).filter_map do |path|
          Date.parse(File.read(path)[/^start_date: "?(\d{4}-\d{2}-\d{2})/, 1].to_s)
        rescue Date::Error
          nil
        end
      end

      def self.reset_meetup_dates!
        @meetup_dates = nil
      end

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        matches = PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end

        matches && event&.meetup? && !MeetupNaming.ignored?(event) && date.present? && event.series.present?
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?
        return [] if event["title"] == expected_title

        location = event.source_location("title")

        [
          Static::Validators::Error.new(
            %(title "#{event["title"]}" should be "#{expected_title}", the group, "Meetup" (unless the group's name already says it is a group) and month. What the organizers call this meetup goes in `subtitle`. Run `bin/rails validate:fix` to rename it and keep the old wording as its subtitle.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def fix
        return unless applicable?
        return if event["title"] == expected_title

        if event["subtitle"].blank?
          subtitle = subtitle_from(event["title"].to_s)
          event["subtitle"] = subtitle if subtitle.present?
        end

        event["title"] = expected_title
        event.save!

        {changed: 1, file_path: @file_path}
      end

      def expected_title
        same_month = self.class.meetup_dates(File.dirname(@file_path.to_s, 2)).count { |other| other.year == date.year && other.month == date.month }
        month = (same_month > 1) ? "#{Date::MONTHNAMES[date.month]} #{date.day}," : Date::MONTHNAMES[date.month]

        "#{self.class.title_name(event.series)} #{month} #{date.year}"
      end

      def subtitle_from(title)
        months = [Date::MONTHNAMES[date.month], GERMAN_MONTHS[date.month - 1]].uniq.map { |name| Regexp.escape(name) }
        match = title.match(/\A(?<prefix>.*?)[\s\-–:,]*\b(?:#{months.join("|")})(?:\s+\d{1,2},?)?\s+#{date.year}(?<suffix>.*)\z/)

        match ||= title.match(/\A(?<prefix>.*?)[\s\-–:,]*\b(?:#{MONTH_NAMES.join("|")})(?:\s+\d{1,2},?)?\s+\d{4}(?<suffix>.*)\z/)
        return (title unless group_name?(title)) unless match

        prefix = match[:prefix].sub(/[\s\-–:,]+\z/, "").sub(/\s+meetup\z/i, "")
        suffix = match[:suffix].sub(/\A[\s\-–:,]+/, "").strip.sub(/\A\((.*)\)\z/, '\1')

        [(prefix unless prefix.empty? || group_name?(prefix)), suffix.presence].compact.join(": ").presence
      end

      private

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end

      def date
        @date ||= Date.parse(event["start_date"].to_s)
      rescue Date::Error
        nil
      end

      def group_name
        event.series["meetup_name"].presence || event.series["name"]
      end

      def group_names
        series = event.series
        [group_name, series["name"], series["meetup_name"], *Array(series["aliases"])].compact_blank.map { |name| normalize(name) }.uniq
      end

      def group_name?(name)
        normalized = normalize(name)
        return true if GENERIC_NAMES.include?(normalized) || group_names.include?(normalized)

        words = words_of(normalized)
        group_names.any? { |group| (words - words_of(group)).empty? }
      end

      def words_of(name)
        name.split(/[^[:alnum:].+#]+/).compact_blank.map { |word| word.delete_suffix("s") }
      end

      def normalize(name)
        name.to_s.sub(/\s+meetup\z/i, "").strip.downcase
      end
    end
  end
end
