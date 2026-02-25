# frozen_string_literal: true

class Locations::StampsController < Locations::BaseController
  def index
    @stamps = @location.stamps

    render_location_view("stamps")
  end

  private

  def redirect_path_helper
    :city_stamps_path
  end
end
