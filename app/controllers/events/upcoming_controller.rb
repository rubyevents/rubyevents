class Events::UpcomingController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @events = Event.includes(:series)
      .where.not(end_date: nil)
      .where(end_date: Date.today..)
      .sort_by(&:start_date)
  end
end
