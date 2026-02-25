# frozen_string_literal: true

class Continents::CountriesController < Continents::BaseController
  def index
    @countries = @continent.countries.sort_by(&:name)

    @events_by_country = @continent.events
      .select { |event| event.country_code.present? }
      .group_by { |event| Country.find_by(country_code: event.country_code) }
      .compact
      .sort_by { |country, _| country&.name.to_s }
      .to_h

    @users_by_country = @continent.users.geocoded
      .group(:country_code)
      .count
      .transform_keys { |code| Country.find_by(country_code: code) }
      .compact
  end
end
