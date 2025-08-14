class Sponsors::MissingController < ApplicationController
  skip_before_action :authenticate_user!

  # GET /sponsors/missing
  def index
    @back_path = sponsors_path
    @events_without_sponsors = Event.conference
      .left_joins(:event_sponsors)
      .where(event_sponsors: {id: nil})
      .past
      .includes(:organisation)
      .order(start_date: :desc)
    @events_by_year = @events_without_sponsors.group_by { |event| event.start_date&.year || "Unknown" }
  end
end
