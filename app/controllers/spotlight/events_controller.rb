class Spotlight::EventsController < ApplicationController
  include TypesenseSearch

  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_available?
      pagy, @events = Event.typesense_search_events(search_query, per_page: LIMIT)
      @total_count = pagy.count
    elsif search_query.present?
      @events = Event.includes(:series).canonical
      @events = @events.ft_search(search_query)
      @total_count = @events.except(:select).count
      @events = @events.limit(LIMIT)
    else
      @events = Event.includes(:series).canonical.past.order(start_date: :desc).limit(LIMIT)
      @total_count = nil
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s]
  end

  helper_method :total_count
  attr_reader :total_count
end
