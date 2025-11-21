class Events::CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_event

  def index
    set_meta_tags(@event)
  end

  private

  def set_event
    @event = Event.includes(:series).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    redirect_to event_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
  end
end
