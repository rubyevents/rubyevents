class Profiles::MapController < ApplicationController
  include ProfileData
  include EventMapMarkers

  def index
    @events = @user.participated_events.includes(:series)
    @countries_with_events = @events.grouped_by_country
    @event_map_markers = event_map_markers(@events)
  end
end
