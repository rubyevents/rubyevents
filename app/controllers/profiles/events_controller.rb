class Profiles::EventsController < ApplicationController
  include ProfileData

  def index
    @events = @user.participated_events.includes(:series).distinct.in_order_of(:attended_as, EventParticipation.attended_as.keys)
    event_participations = @user.event_participations.includes(:event).where(event: @events)
    @participations = event_participations.index_by(&:event_id)

    # Merge verified-only events (not already in participated_events)
    @verified_event_ids = @user.verified_event_ids
    verified_only_event_ids = @verified_event_ids - @events.map(&:id).to_set
    if verified_only_event_ids.any?
      verified_only_events = Event.includes(:series).where(id: verified_only_event_ids)
      @events = @events.to_a + verified_only_events.to_a
    end

    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }
  end
end
