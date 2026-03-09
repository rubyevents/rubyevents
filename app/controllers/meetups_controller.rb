class MeetupsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /meetups
  def index
    @meetups = Event.includes(:series, :keynote_speakers)
      .where(kind: :meetup, end_date: Date.today..)
      .order(start_date: :asc)
  end
end
