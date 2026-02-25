# frozen_string_literal: true

class States::CitiesController < States::BaseController
  def index
    @cities = @state.cities
    @sort = params[:sort].presence || "events"

    @cities = case @sort
    when "name"
      @cities.sort_by(&:name)
    else
      @cities.sort_by { |c| -c.events_count }
    end
  end
end
