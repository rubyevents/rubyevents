class Events::SponsorsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_event

  # GET /events/:event_slug/sponsors
  def index
    @sponsors_by_tier = @event.sponsors.includes(:organization).group_by(&:tier)
  end

  private

  def set_event
    @event = Event.includes(sponsors: :organization).find_by(slug: params[:event_slug])
    set_meta_tags(@event)

    redirect_to events_path, status: :moved_permanently, notice: "Event not found" if @event.blank?
  end
end
