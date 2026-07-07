# frozen_string_literal: true

module Static
  module Validators
    class TalkDates
      PATTERNS = [
        "**/videos.yml"
      ].freeze

      IGNORE_PUBLISHED_AT_BEFORE_DATE = "validator:disable published_at_before_date"

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
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

        return [] unless document.root

        @start_date, @end_date, @timezone, pre_date = event_context
        @range_start = [pre_date, @start_date].compact.min

        document.root.each.flat_map do |video|
          nested = Array(video["talks"]&.each&.to_a)

          talk_errors(video) + nested.flat_map { |talk| talk_errors(talk) }
        end
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def event_context
        event_path = File.join(File.dirname(@file_path), "event.yml")
        return [nil, nil, nil, nil] unless File.exist?(event_path)

        document = Yerba.parse_file(event_path)

        [
          parse_date(document["start_date"]&.value),
          parse_date(document["end_date"]&.value),
          document["timezone"]&.value,
          parse_date(document["pre_date"]&.value)
        ]
      end

      def talk_errors(node)
        return [] if Talk::SUPPLEMENTARY_KINDS.include?(node.value_at("kind"))

        errors = []

        date = parse_date(node.value_at("date"))
        published_at = published_local_date(node.value_at("published_at"))

        if date && published_at && published_at < date
          location = node["published_at"]&.location

          unless ignored?(location&.start_line, IGNORE_PUBLISHED_AT_BEFORE_DATE)
            errors << Static::Validators::Error.new(
              "published_at (#{node.value_at("published_at")}) must not be before the talk date (#{node.value_at("date")})",
              file_path: @file_path,
              line: location&.start_line || 1,
              end_line: location&.end_line
            )
          end
        end

        if date && @range_start && @end_date && !date.between?(@range_start, @end_date)
          location = node["date"]&.location

          errors << Static::Validators::Error.new(
            "date (#{node.value_at("date")}) must be within the event dates (#{@range_start} to #{@end_date}). " \
            "If this is a pre-conference activity (e.g. workshops or a pre-party) held before the event, add a pre_date to the event.yml.",
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end

        errors
      end

      def ignored?(line_number, marker)
        return false unless line_number

        file_lines[line_number - 1].to_s.include?(marker)
      end

      def file_lines
        @file_lines ||= File.readlines(@file_path)
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error, TypeError
        nil
      end

      def published_local_date(value)
        string = value.to_s.strip

        return nil if string.empty?
        return parse_date(string) unless string.include?("T")

        time = Time.parse(string)
        zone = @timezone && Time.find_zone(@timezone)

        (zone ? time.in_time_zone(zone) : time).to_date
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
