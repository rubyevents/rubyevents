# frozen_string_literal: true

module Static
  # A location ends in its country written out: "London, United Kingdom", "Berkeley, CA, United States".
  # The last part is looked up as the country, so a code can land in the wrong one: "Berkeley, CA" shows up in Canada.
  # Online events and meetup groups use "online".
  #
  class LocationCountryValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      location = value.to_s.strip
      return if written_out?(location)

      suggested = suggested_location(record)

      message = if suggested
        %("#{location}" should end in the country written out: "#{suggested}". Run `bin/rails validate:fix` to change it.)
      else
        %("#{location}" should end in the country written out, like "Portland, OR, United States" or "London, United Kingdom", or be "online".)
      end

      record.errors.add(attribute, message)
    end

    def fix(record)
      return 0 if written_out?(location_of(record))

      suggested = suggested_location(record)
      return 0 if suggested.blank?

      record["location"] = suggested

      1
    end

    def suggested_location(record)
      parts = location_of(record).split(",").map(&:strip)
      term = parts.last
      return nil unless abbreviated?(term)

      default_country = default_country(record)
      united_states = ::Country.find_by(country_code: "US")

      if subdivision_of?(default_country, term)
        [*parts, default_country.name].join(", ")
      elsif subdivision_of?(united_states, term)
        [*parts, united_states.name].join(", ") unless ISO3166::Country.new(term)&.alpha2
      elsif (country = ::Country.find(term))
        [*parts[...-1], country.name].join(", ")
      end
    end

    private

    def location_of(record)
      record["location"].to_s.strip
    end

    def written_out?(location)
      return true if location.blank? || location.casecmp?("online")

      term = location.split(",").last.strip

      !abbreviated?(term) && ::Country.find(term).present?
    end

    def abbreviated?(term)
      term.to_s.match?(/\A[[:upper:]]{2,3}\z/)
    end

    def subdivision_of?(country, term)
      country.present? && country.subdivisions.key?(term)
    end

    def default_country(record)
      series = record.is_a?(Static::EventSeries) ? record : record.series

      ::Country.find_by(country_code: series&.[]("default_country_code"))
    end
  end
end
