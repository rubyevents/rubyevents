class Events::PastController < ApplicationController
  include ContinentFilterable

  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @events = filter_by_continent(
      Event.includes(:series, :keynote_speakers).where(end_date: ...Date.today)
    ).order(start_date: :desc).limit(50)
  end
end
