# frozen_string_literal: true

module Static
  # City, state and country of a record with a `location` in "City, State, Country" format, like an event or a meetup group.
  module LocationParsing
    def country
      return nil if self["location"].blank?

      Country.find(self["location"].to_s.split(",").last&.strip)
    end

    def city
      return nil if self["location"].blank?

      parts = self["location"].to_s.split(",").map(&:strip)
      parts.first if parts.size >= 2
    end

    def state_code
      parsed_state_code || featured_city&.state_code.presence
    end

    def resolved_city
      featured_city&.name || city
    end

    def featured_city
      return @featured_city if defined?(@featured_city)

      @featured_city = find_featured_city
    end

    def find_featured_city
      return nil if city.blank?

      Static::City.find_by_name_or_alias(city, country_code: country&.alpha2)
    end

    def parsed_state_code
      return nil if self["location"].blank? || country.blank?
      return nil unless State.supported_country?(country)

      parts = self["location"].to_s.split(",").map(&:strip)
      return nil if parts.size < 3

      state = State.find(country: country, term: parts[-2])
      state&.code
    end
  end
end
