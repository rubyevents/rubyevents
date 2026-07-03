class Profiles::EventsController < ApplicationController
  include ProfileData

  def index
    @events = @user.participated_events.includes(:series).in_order_of(:attended_as, EventParticipation.attended_as.keys)
    event_participations = @user.event_participations.includes(:event).where(event: @events).in_order_of(:attended_as, EventParticipation.attended_as.keys)

    @participations = event_participations.group_by(&:event_id).transform_values(&:first)
    @checked_in_event_ids = @user.checked_in_event_ids

    checked_in_only_event_ids = @checked_in_event_ids - @events.map(&:id).to_set

    if checked_in_only_event_ids.any?
      checked_in_only_events = Event.includes(:series).where(id: checked_in_only_event_ids)
      @events = @events.to_a + checked_in_only_events.to_a
    end

    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }
  end
end
