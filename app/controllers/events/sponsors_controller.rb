class Events::SponsorsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_event

  # GET /events/:event_slug/sponsors
  def index
    @sponsors_by_tier = @event.event_sponsors.includes(:sponsor).group_by(&:tier)
  end

  private

  def set_event
    @event = Event.includes(event_sponsors: :sponsor).find_by(slug: params[:event_slug])

    redirect_to events_path, status: :moved_permanently, notice: "Event not found" if @event.blank?
  end
end
