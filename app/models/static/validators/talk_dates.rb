# frozen_string_literal: true

module Static
  module Validators
    class TalkDates
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      def initialize(file_path:)
        @file_path = file_path
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?

        document = Yerba.parse_file(@file_path)
        return [] unless document.root

        @start_date, @end_date = event_dates

        document.root.each.flat_map do |video|
          nested = Array(video["talks"]&.each&.to_a)

          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      private

      def event_dates
        event_path = File.join(File.dirname(@file_path), "event.yml")
        return [nil, nil] unless File.exist?(event_path)

        document = Yerba.parse_file(event_path)

        [parse_date(document["start_date"]&.value), parse_date(document["end_date"]&.value)]
      end

      def talk_errors(node)
        errors = []

        date = parse_date(node.value_at("date"))
        published_at = parse_date(node.value_at("published_at"))

        if date && published_at && published_at < date
          location = node["published_at"]&.location

          errors << Static::Validators::Error.new(
            "published_at (#{node.value_at("published_at")}) must not be before the talk date (#{node.value_at("date")})",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        if date && @start_date && @end_date && !date.between?(@start_date, @end_date)
          location = node["date"]&.location

          errors << Static::Validators::Error.new(
            "date (#{node.value_at("date")}) must be within the event dates (#{@start_date} to #{@end_date})",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error, TypeError
        nil
      end
    end
  end
end
