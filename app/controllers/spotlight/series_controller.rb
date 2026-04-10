class Spotlight::SeriesController < ApplicationController
  include SpotlightSearch

  LIMIT = 8

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @series, @total_count = search_backend_class.search_series(search_query, limit: LIMIT)
    else
      @series = EventSeries.joins(:events).distinct.order(name: :asc).limit(LIMIT)
      @total_count = nil
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s].presence
  end

  helper_method :total_count
  attr_reader :total_count
end
