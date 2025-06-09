class Events::PastController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @events = Event.includes(:organisation, :keynote_speakers)
      .where(end_date: ..Date.today)
      .order(start_date: :desc)
      .select { |event| event.static_metadata.conference? }
  end
end
