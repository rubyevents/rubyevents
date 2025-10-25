class StampsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @stamps = Stamp.all
    @event_stamps = Stamp.event_stamps.sort_by(&:name)
    @stamps_by_continent = Stamp.grouped_by_continent
    @missing_stamp_countries = Stamp.missing_for_events
  end
end
