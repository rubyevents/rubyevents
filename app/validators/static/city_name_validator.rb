# frozen_string_literal: true

module Static
  class CityNameValidator < ActiveModel::EachValidator
    def validate_each(event, attribute, value)
      city = value&.split(",")&.first&.strip
      return if city.blank?

      canonical = Static::City.alias_lookup[city.downcase]&.name
      return unless canonical && canonical.downcase != city.downcase

      event.errors.add(attribute, %(uses city alias "#{city}" instead of canonical name "#{canonical}"))
    end
  end
end
