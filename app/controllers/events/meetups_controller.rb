class Events::MeetupsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /meetups
  def index
    @meetups = Event.where(kind: :meetup)
      .joins(:talks)
      .where(talks: {date: 1.year.ago..})
      .distinct
      .includes(:series)
      .order(:name)
  end
end
