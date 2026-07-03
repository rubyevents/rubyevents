class Countries::CitiesController < Countries::BaseController
  def index
    @cities = City.for_country(@country.alpha2)
    @sort = params[:sort].presence || "events"
    @show_states = @country&.states?

    @cities = case @sort
    when "name"
      @cities.sort_by(&:name)
    else
      @cities.sort_by { |c| -c.events_count }
    end
  end
end
