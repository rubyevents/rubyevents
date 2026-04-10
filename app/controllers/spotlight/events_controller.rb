class Spotlight::EventsController < ApplicationController
  include SpotlightSearch

  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present?
      @events, @total_count = search_backend_class.search_events(search_query, limit: LIMIT)
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
