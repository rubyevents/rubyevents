# frozen_string_literal: true

module Static
  # Events link to cities by [city, country_code, state_code], so an event without a
  # state ("Sendai, Japan") doesn't show up on a city page whose City record has one
  # ("Sendai, Miyagi, Japan"). Same-named cities in different states are left alone.
  #
  class CityStateConsistencyValidator < ActiveModel::Validator
    def validate(event)
      return if event.state_code.present? || event.resolved_city.blank? || event.country.blank?

      suggestions = locations_with_state(event.class)[[event.resolved_city.downcase, event.country.alpha2]]
      return if suggestions.blank?

      event.errors.add(:location, %("#{event.location}" has no state, but other events in this city use #{suggestions.map { |location| %("#{location}") }.join(" or ")}. Mixed formats keep events off the city page.))
    end

    private

    def locations_with_state(model)
      Yerba::Record::Validations.cached(self.class, model) do
        model.all
          .select { |event| event.state_code.present? && event.resolved_city.present? && event.country.present? }
          .group_by { |event| [event.resolved_city.downcase, event.country.alpha2] }
          .transform_values { |events| events.map(&:location).tally.sort_by { |_location, count| -count }.map(&:first) }
      end
    end
  end
end
