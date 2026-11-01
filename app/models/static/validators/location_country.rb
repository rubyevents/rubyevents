# frozen_string_literal: true

module Static
  module Validators
    # A location ends in its country written out: "London, United Kingdom", "Berkeley, CA, United States".
    # The last part is looked up as the country, so a code can land in the wrong one: "Berkeley, CA" shows up in Canada.
    # Online events and meetup groups use "online".
    #
    class LocationCountry
      PATTERNS = [
        "**/event.yml",
        "**/series.yml"
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

        matches && record.present?
      end

      def errors
        @errors ||= validate
      end

      def validate
        return [] unless applicable?
        return [] if written_out?

        source_location = record.source_location("location")

        [
          Static::Validators::Error.new(
            message,
            file_path: @file_path,
            line: source_location&.start_line || 1,
            end_line: source_location&.end_line
          )
        ]
      end

      def fix
        return unless applicable?
        return if written_out?
        return if suggested_location.blank?

        record["location"] = suggested_location
        record.save!

        {changed: 1, file_path: @file_path}
      end

      def suggested_location
        parts = location.split(",").map(&:strip)
        term = parts.last
        return nil unless abbreviated?(term)

        if subdivision_of?(default_country, term)
          [*parts, default_country.name].join(", ")
        elsif subdivision_of?(united_states, term)
          [*parts, united_states.name].join(", ") unless ISO3166::Country.new(term)&.alpha2
        elsif (country = Country.find(term))
          [*parts[...-1], country.name].join(", ")
        end
      end

      private

      def message
        if suggested_location
          %(Location "#{location}" should end in the country written out: "#{suggested_location}". Run `bin/rails validate:fix` to change it.)
        else
          %(Location "#{location}" should end in the country written out, like "Portland, OR, United States" or "London, United Kingdom", or be "online".)
        end
      end

      def written_out?
        return true if location.blank? || location.casecmp?("online")

        term = location.split(",").last.strip

        !abbreviated?(term) && Country.find(term).present?
      end

      def abbreviated?(term)
        term.match?(/\A[[:upper:]]{2,3}\z/)
      end

      def subdivision_of?(country, term)
        country.present? && country.subdivisions.key?(term)
      end

      def default_country
        return @default_country if defined?(@default_country)

        series = record.is_a?(Static::EventSeries) ? record : record.series
        @default_country = Country.find_by(country_code: series&.[]("default_country_code"))
      end

      def united_states
        Country.find_by(country_code: "US")
      end

      def location
        record["location"].to_s.strip
      end

      def record
        @record ||= record_class.in_file(@file_path.to_s, document: @document).first
      end

      def record_class
        (File.basename(@file_path.to_s) == "series.yml") ? Static::EventSeries : Static::Event
      end
    end
  end
end
