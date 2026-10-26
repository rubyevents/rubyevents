# frozen_string_literal: true

module Static
  module Validators
    class MeetupSeriesFrequency
      PATTERNS = [
        "**/series.yml"
      ].freeze

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
        return [] unless declared?

        location = series.source_location("frequency")

        [
          Static::Validators::Error.new(
            %(frequency "#{series["frequency"]}" is set on a meetup series. How often a group meets is worked out from its meetup dates. Run `bin/rails validate:fix` to remove it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        ]
      end

      def fix
        return unless declared?

        series.delete("frequency")
        series.save!

        {changed: 1, file_path: @file_path}
      end

      private

      def series
        @series ||= Static::EventSeries.in_file(@file_path.to_s, document: @document).first
      end

      def declared?
        applicable? && series && series["kind"] == "meetup" && series["frequency"].present?
      end
    end
  end
end
