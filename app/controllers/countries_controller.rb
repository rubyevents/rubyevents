class CountriesController < ApplicationController
  include EventMapMarkers

  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @countries_by_continent = Event.distinct
      .where.not(country_code: [nil, ""])
      .pluck(:country_code)
      .filter_map { |code| Country.find_by(country_code: code) }
      .group_by(&:continent)
      .sort_by { |continent, _| continent || "ZZ" }
      .to_h

    @events_by_country = Event.includes(:series)
      .where.not(country_code: [nil, ""])
      .grouped_by_country
      .to_h

    @users_by_country = User.geocoded
      .group(:country_code)
      .count
      .transform_keys { |code| Country.find_by(country_code: code) }
      .compact

    @event_map_markers = event_map_markers
  end

  def show
    @country = Country.find(params[:slug])

    if @country.blank?
      head :not_found
      return
    end

    @events = @country.events.includes(:series).order(start_date: :desc)

    @featured_cities = FeaturedCity.where(country_code: @country.alpha2).order(:name)
    @featured_city_names = @featured_cities.pluck(:city).map(&:downcase).to_set

    @events_by_city = @events
      .select { |event| event.location.present? }
      .reject { |event| @featured_city_names.include?(event.city&.downcase) }
      .group_by(&:location)
      .sort_by { |city, _events| city }
      .to_h

    @users = @country.users.geocoded.order(talks_count: :desc)
    @stamps = @country.stamps
  end
end
