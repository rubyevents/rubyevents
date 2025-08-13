class StampsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @stamps = Stamp.all
    @stamps_by_continent = Stamp.grouped_by_continent
    @missing_stamp_countries = Stamp.missing_for_events
  end
end
