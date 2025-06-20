class Events::CountriesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @countries_by_continent = Event.all.map { |event| event.static_metadata&.country }.uniq.group_by { |country| country&.continent || "Unknown" }.sort_by { |key, _value| key || "ZZ" }.to_h
    @events_by_country = Event.all.sort_by { |event| event.static_metadata&.home_sort_date || Time.at(0).to_date }.reverse.group_by { |event| event.static_metadata&.country || "Unknown" }.sort_by { |key, value| (key.is_a?(String) ? key : key&.iso_short_name) || "ZZ" }.to_h
  end

  def show
    @country = Country.find(params[:country])
    if @country.present?
      @events = Event.includes(:organisation).all.select { |event| event.static_metadata&.country == @country }.sort_by { |event| event.static_metadata&.home_sort_date || Time.at(0).to_date }.reverse
    else
      head :not_found
    end
  end
end
