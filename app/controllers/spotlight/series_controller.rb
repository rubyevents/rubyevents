class Spotlight::SeriesController < ApplicationController
  LIMIT = 8

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_enabled?
      pagy, @series = EventSeries.typesense_search_series(search_query, per_page: LIMIT)
      @total_count = pagy.count
    else
      @series = EventSeries.joins(:events).distinct.order(name: :asc)
      @series = @series.where("event_series.name LIKE ?", "%#{search_query}%") if search_query.present?
      @total_count = @series.count
      @series = @series.limit(LIMIT)
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

  def typesense_enabled?
    EventSeries.respond_to?(:typesense_search_series)
  end
end
