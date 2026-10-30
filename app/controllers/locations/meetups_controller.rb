# frozen_string_literal: true

class Locations::MeetupsController < Locations::BaseController
  def index
    @meetup_groups = location_meetup_groups

    render_location_view("meetups")
  end

  private

  def location_meetup_groups
    location_columns = @location.events.where_values_hash.slice("country_code", "state_code", "city")

    met_here = EventSeries.where(id: @location.events.where(kind: :meetup).select(:event_series_id))
    groups = location_columns.any? ? EventSeries.where(id: EventSeries.meetup_groups.where(location_columns).select(:id)).or(met_here) : met_here

    groups.includes(:events).order(:name)
  end

  def redirect_path_helper
    :city_meetups_path
  end
end
