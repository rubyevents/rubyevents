class Events::CountriesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @countries_by_continent = Event.all.map { |event| event.static_metadata.country }.uniq.group_by { |country| country&.continent || nil }.sort_by { |key, _value| key || "ZZ" }.to_h
    @events_by_country = Event.all.sort_by { |event| event.static_metadata.home_sort_date }.reverse.group_by { |event| event.static_metadata.country }.sort_by { |key, value| key&.iso_short_name || "ZZ" }.to_h
  end

  def show
    @country = Country.find(params[:country])
    @events = Event.all.select { |event| event.static_metadata.country == @country }.sort_by { |event| event.static_metadata.home_sort_date }.reverse
  end
end
