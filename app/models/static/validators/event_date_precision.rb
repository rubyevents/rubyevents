# frozen_string_literal: true

module Static
  module Validators
    class EventDatePrecision
      PATTERNS = [
        "**/event.yml"
      ].freeze

      DATE_FIELDS = %w[start_date end_date].freeze

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
        mismatched_dates.map do |field, expected|
          location = document[field]&.location

          Static::Validators::Error.new(
            %(#{field} (#{document[field]}) must be the last day of the #{precision} (#{expected}) when date_precision is "#{precision}". Run `bin/rails validate:fix` to update it.),
            file_path: @file_path,
            line: location&.start_line || 1,
            end_line: location&.end_line
          )
        end
      end

      def fix
        return unless applicable?

        changes = mismatched_dates
        return if changes.empty?

        changes.each { |field, expected| document[field] = expected.iso8601 }
        document.save!(apply: true)

        {changed: changes.size, file_path: @file_path}
      end

      private

      def document
        @document ||= Yerba.parse_file(@file_path.to_s)
      end

      def precision
        document["date_precision"].to_s
      end

      def mismatched_dates
        return [] unless applicable?
        return [] unless precision.in?(%w[month year])

        DATE_FIELDS.filter_map do |field|
          date = parse_date(document[field])
          next unless date

          expected = (precision == "year") ? date.end_of_year : date.end_of_month
          next if date == expected

          [field, expected]
        end
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error, TypeError
        nil
      end
    end
  end
end
