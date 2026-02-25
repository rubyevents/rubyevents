class Sponsors::MissingController < ApplicationController
  skip_before_action :authenticate_user!

  # GET /sponsors/missing
  def index
    @back_path = organizations_path
    @events_without_sponsors = Event.not_meetup
      .left_joins(:sponsors)
      .where(sponsors: {id: nil})
      .past
      .includes(:series)
      .order(start_date: :desc)
    @events_by_year = @events_without_sponsors.group_by { |event| event.start_date&.year || "Unknown" }
  end
end
