class Events::TicketsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  before_action :set_event

  def show
  end

  private

  def set_event
    @event = Event.includes(series: :events).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    set_meta_tags(@event)

    redirect_to event_tickets_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
    redirect_to event_path(@event) unless @event.tickets?
  end
end
