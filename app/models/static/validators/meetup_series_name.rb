# frozen_string_literal: true

module Static
  module Validators
    class MeetupSeriesName
      PATTERNS = [
        "**/series.yml"
      ].freeze

      SUFFIX = /\s+Meetup\z/i

      def initialize(file_path:, document: nil)
        @file_path = file_path
        @document = document
      end

      def applicable?
        return false unless File.exist?(@file_path)

        PATTERNS.any? do |pattern|
          File.fnmatch?(pattern, @file_path, File::FNM_PATHNAME | File::FNM_DOTMATCH)
        end
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless expected_name

        location = series.source_location("name")

        [
          Static::Validators::Error.new(
            %(name "#{series["name"]}" ends in "Meetup", expected "#{expected_name}". The series is named after the group, and its meetups are titled "<name> Meetup <Month> <Year>". Run `bin/rails validate:fix` to rename it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def fix
        return unless expected_name

        series["name"] = expected_name
        series.save!

        {changed: 1, file_path: @file_path}
      end

      private

      def series
        @series ||= Static::EventSeries.in_file(@file_path.to_s, document: @document).first
      end

      # A meetup series nested under a parent of the same name keeps "Meetup" to tell the two apart: "SF Ruby Meetup" under "SF Ruby".
      def expected_name
        return @expected_name if defined?(@expected_name)

        @expected_name = if applicable? && series && series["kind"] == "meetup" && series["name"].to_s.match?(SUFFIX)
          name = series["name"].to_s.sub(SUFFIX, "")

          name unless series.parent&.[]("name") == name
        end
      end
    end
  end
end
