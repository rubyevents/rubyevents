class Events::MeetupsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /events/meetups
  def index
    @meetups = Event.where(kind: :meetup)
      .left_joins(:talks)
      .distinct
      .includes(:series)
      .group("events.id")
      .order("max(talks.date) DESC")
  end
end
