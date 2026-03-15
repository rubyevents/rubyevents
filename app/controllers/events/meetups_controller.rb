class Events::MeetupsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /events/meetups
  def index
    @meetups = Event.where(kind: :meetup)
      .joins(:talks)
      .distinct
      .includes(:series)
      .group("events.id")
      .order("max(talks.date) DESC")

    @countries_by_continent = Event.distinct
      .where(kind: :meetup)
      .where.not(country_code: [nil, ""])
      .pluck(:country_code)
      .filter_map { |code| Country.find_by(country_code: code) }
      .group_by(&:continent)
      .sort_by { |continent, _| continent&.name || "ZZ" }
      .to_h

    @events_by_country = Event.includes(:series)
      .where(kind: :meetup)
      .where.not(country_code: [nil, ""])
      .grouped_by_country
      .to_h
  end
end
