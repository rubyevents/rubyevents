# frozen_string_literal: true

class Locations::MeetupsController < Locations::BaseController
  def index
    @meetups = @location.events
      .joins(:series)
      .where(event_series: {kind: :meetup})
      .includes(:series)
      .order("event_series.name", start_date: :desc)

    render_location_view("meetups")
  end
end
