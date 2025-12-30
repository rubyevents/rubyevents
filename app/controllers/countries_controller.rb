class CountriesController < ApplicationController
  include EventMapMarkers

  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @countries_by_continent = Event.all.map do |event|
      event.country
    end.uniq.group_by { |country| country&.continent || "Unknown" }.sort_by { |key, _value| key || "ZZ" }.to_h
    @events_by_country = Event.all.sort_by { |e| event_sort_date(e) }.reverse
      .group_by { |e| e.country || "Unknown" }
      .sort_by { |key, _| (key.is_a?(String) ? key : key&.iso_short_name) || "ZZ" }.to_h
    @users_by_country = calculate_users_by_country
    @event_map_markers = event_map_markers
  end

  def show
    @country = Country.find(params[:country])
    if @country.present?
      @events = Event.includes(:series).all.select do |event|
        event.country == @country
      end.sort_by { |e| event_sort_date(e) }.reverse

      @events_by_city = @events
        .select { |event| event.static_metadata&.location.present? }
        .group_by { |event| event.static_metadata&.location }
        .sort_by { |city, _events| city }
        .to_h

      @users = User.where("location LIKE ?", "%#{@country.translations["en"]}%").order(talks_count: :desc)
      @stamps = Stamp.all.select { |stamp| stamp.has_country? && stamp.country == @country }
    else
      head :not_found
    end
  end

  private

  def calculate_users_by_country
    users_by_country = {}

    User.where.not(location: [nil, ""]).find_each do |user|
      if (country = user.location_info.country)
        users_by_country[country] ||= Set.new
        users_by_country[country] << user
      end
    end

    users_by_country.transform_values(&:size)
  end
end
