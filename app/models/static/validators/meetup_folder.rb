# frozen_string_literal: true

module Static
  module Validators
    # A meetup's folder, and so its id, is its series and date: "data/lrug/lrug-2026-01-12/event.yml",
    # with a counter for another meetup of the series on the same day: "lrug-2026-01-12-2".
    class MeetupFolder
      PATTERNS = [
        "**/event.yml"
      ].freeze

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        matches = PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end

        matches && event&.meetup? && !MeetupNaming.ignored?(event)
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?
        return [] if expected_ids.include?(event["id"].to_s)

        location = event.source_location("id")

        [
          Static::Validators::Error.new(
            %(meetup id "#{event["id"]}" should be "#{expected_ids.first || "#{series_id}-YYYY-MM-DD"}", its series and date, with "-2", "-3", ... for another meetup on the same day. The folder is named after the id.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      private

      def series_id
        File.basename(File.dirname(@file_path.to_s, 2))
      end

      def expected_ids
        date = event["start_date"].to_s
        return [] unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)

        base = "#{series_id}-#{date}"

        [base, *(2..9).map { |counter| "#{base}-#{counter}" }]
      end

      def event
        @event ||= Static::Event.in_file(@file_path.to_s, document: @document).first
      end
    end
  end
end
