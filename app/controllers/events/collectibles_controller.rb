class Events::CollectiblesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_event

  # GET /events/:event_slug/collectibles
  def index
    @stamps = Stamp.for_event(@event)
    @stickers = @event.stickers
  end

  private

  def set_event
    @event = Event.find_by(slug: params[:event_slug])

    redirect_to events_path, status: :moved_permanently, notice: "Event not found" if @event.blank?
    set_meta_tags(@event)
  end
end
