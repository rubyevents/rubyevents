class Events::PastController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @events = Event.includes(:series, :keynote_speakers)
      .not_meetup
      .where(end_date: ...Date.today)
      .order(start_date: :desc)
      .limit(50)
  end
end
