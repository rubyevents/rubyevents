class Events::CitiesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @events_by_city = Event.all
      .select { |event| event.static_metadata&.location.present? }
      .sort_by { |event| event.static_metadata&.home_sort_date || Time.at(0).to_date }
      .reverse
      .group_by { |event| event.static_metadata&.location }
      .sort_by { |city, _events| city }
      .to_h

    @cities_by_country = @events_by_city.keys.group_by { |city|
      events = @events_by_city[city]
      country = events.first.country
      country&.translations&.dig("en") || "Unknown"
    }.sort_by { |country, _cities| country }.to_h

    @clean_city_names = {}
    @events_by_city.each do |city, events|
      country = events.first.country
      country_name = country&.translations&.dig("en")
      clean_name = city

      if country_name && city.include?(", #{country_name}")
        clean_name = city.gsub(", #{country_name}", "")
      end

      @clean_city_names[city] = clean_name
    end

    @countries_by_continent = @cities_by_country.keys.group_by { |country_name|
      city = @cities_by_country[country_name].first
      events = @events_by_city[city]
      country = events.first.country
      country&.continent || "Unknown"
    }.sort_by { |continent, _countries| continent || "ZZ" }.to_h
  end

  def show
    @city = params[:city]
    @events = Event.includes(:series).all
      .select { |event| event.static_metadata&.location&.parameterize == @city }
      .sort_by { |event| event.static_metadata&.home_sort_date || Time.at(0).to_date }
      .reverse

    if @events.empty?
      redirect_to cities_path
    else
      @country = @events.first.country
    end
  end
end
