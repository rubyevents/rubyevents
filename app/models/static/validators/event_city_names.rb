# frozen_string_literal: true

module Static
  module Validators
    class EventCityNames
      def initialize(file_path:)
        @file_path = file_path
      end

      PATTERNS = [
        "**/event.yml"
      ].freeze

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
        location = document["location"]

        city_part = location&.value&.split(",")&.first&.strip
        return [] if city_part.blank?

        alias_to_canonical = Static::City.alias_lookup
        canonical = alias_to_canonical[city_part.downcase]&.name

        return [] unless canonical && canonical.downcase != city_part.downcase

        [
          Static::Validators::Error.new(
            "Location uses city alias \"#{city_part}\" instead of canonical name \"#{canonical}\"",
            file_path: @file_path,
            line: location&.location&.start_line || 1,
            end_line: location&.location&.end_line
          )
        ]
      end
    end
  end
end
