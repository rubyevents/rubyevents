class StampsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @stamps = Static::Stamp.all
    @event_stamps = Static::Stamp.event_stamps.sort_by(&:name)
    @stamps_by_continent = Static::Stamp.grouped_by_continent
    @missing_stamp_countries = Static::Stamp.missing_for_events
  end
end
