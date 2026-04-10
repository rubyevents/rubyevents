class Spotlight::LocationsController < ApplicationController
  include SpotlightSearch

  LIMIT = 10

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @locations, @total_count = search_backend_class.search_locations(search_query, limit: LIMIT)

      if @locations.empty?
        @geocoded_locations = geocode_query(search_query)
      end
    else
      @locations = []
      @total_count = nil
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def geocode_query(query)
    results = Geocoder.search(query).first(5)
    return [] if results.empty?

    results.filter_map do |result|
      next unless result.latitude && result.longitude

      {
        name: result.city || result.state || result.country || query,
        latitude: result.latitude,
        longitude: result.longitude,
        country: result.country,
        type: result.city.present? ? :city : :region
      }
    end
  end

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count
end
