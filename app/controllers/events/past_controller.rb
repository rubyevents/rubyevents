class Events::PastController < ApplicationController
  include ContinentFilterable
  include KindFilterable

  skip_before_action :authenticate_user!, only: %i[index]

  def index
    events = filter_by_continent(Event.ruby_focused.includes(:series, :keynote_speakers).where(end_date: ...Date.today))
    @kind_counts = kind_counts(events)

    @events = filter_by_kind(events).order(start_date: :desc).limit(50)
  end
end
