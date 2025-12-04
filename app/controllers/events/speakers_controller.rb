class Events::SpeakersController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event, only: %i[index]

  def index
  end

  private

  def set_event
    @event = Event.includes(:series, talks: {speakers: :connected_accounts}).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    set_meta_tags(@event)

    redirect_to schedule_event_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
  end
end
