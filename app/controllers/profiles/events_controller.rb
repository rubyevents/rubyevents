class Profiles::EventsController < ApplicationController
  include ProfileData

  def index
    @events = @user.participated_events.includes(:series).distinct.in_order_of(:attended_as, EventParticipation.attended_as.keys)
    event_participations = @user.event_participations.includes(:event).where(event: @events)
    @participations = event_participations.index_by(&:event_id)
    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }
  end
end
