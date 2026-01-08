# frozen_string_literal: true

class OnlineController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @location = OnlineLocation.instance
    @events = @location.events.upcoming.order(start_date: :asc)
  end
end
