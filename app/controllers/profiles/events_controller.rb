class Profiles::EventsController < ApplicationController
  include ProfileData

  def index
    @events = @user.participated_events.includes(:series)
    @participations = @user.event_participations.index_by(&:event_id)
    @checked_in_event_ids = @user.checked_in_event_ids

    checked_in_only_event_ids = @checked_in_event_ids - @events.map(&:id).to_set

    if checked_in_only_event_ids.any?
      checked_in_only_events = Event.includes(:series).where(id: checked_in_only_event_ids)
      @events = @events.to_a + checked_in_only_events.to_a
    end

    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }
  end
end
