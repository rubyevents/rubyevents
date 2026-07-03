class Events::VenuesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  before_action :set_event

  def show
    unless @event.venue.exist?
      render :missing_venue
      return
    end

    @venue = @event.venue
  end

  private

  def set_event
    @event = Event.includes(series: :events).find_by(slug: params[:event_slug])
    return redirect_to(root_path, status: :moved_permanently) unless @event

    set_meta_tags(@event)

    redirect_to event_venue_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
  end
end
