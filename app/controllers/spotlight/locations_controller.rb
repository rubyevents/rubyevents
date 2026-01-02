class Spotlight::LocationsController < ApplicationController
  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    @locations = search_locations(search_query)
    @total_count = @locations.size

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count

  def search_locations(query)
    return [] if query.blank?

    results = []
    query_downcase = query.downcase

    countries_with_events.each do |country_code, event_count|
      country = Country.find(country_code)
      next unless country

      country_name = country.common_name || country.iso_short_name
      if country_name.downcase.include?(query_downcase) ||
          country_code.downcase.include?(query_downcase)
        results << {
          type: :country,
          name: country_name,
          country_code: country_code,
          emoji_flag: country.emoji_flag,
          event_count: event_count,
          path: country_path(country_code.downcase)
        }
      end
    end

    cities_with_countries.each do |city, country_code, event_count|
      country = Country.find(country_code)
      country_name = country&.common_name || country&.iso_short_name || country_code

      if city.downcase.include?(query_downcase)
        results << {
          type: :city,
          name: city,
          country_name: country_name,
          country_code: country_code,
          emoji_flag: country&.emoji_flag,
          event_count: event_count,
          path: city_path(city.parameterize)
        }
      end
    end

    results.sort_by do |r|
      name = r[:name]
      exact_match = (name.downcase == query_downcase) ? 0 : 1
      starts_with = name.downcase.start_with?(query_downcase) ? 0 : 1
      [exact_match, starts_with, -r[:event_count]]
    end.first(LIMIT)
  end

  def countries_with_events
    @countries_with_events ||= Event.where.not(country_code: [nil, ""])
      .group(:country_code)
      .count
  end

  def cities_with_countries
    @cities_with_countries ||= Event.where.not(city: [nil, ""])
      .where.not(country_code: [nil, ""])
      .group(:city, :country_code)
      .count
      .map { |(city, country_code), count| [city, country_code, count] }
  end
end
