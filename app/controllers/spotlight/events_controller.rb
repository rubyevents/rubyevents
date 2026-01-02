class Spotlight::EventsController < ApplicationController
  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    if search_query.present? && typesense_enabled?
      pagy, @events = Event.typesense_search_events(search_query, per_page: LIMIT)
      @total_count = pagy.count
    else
      @events = Event.includes(:series).canonical.order(date: :desc)
      @events = @events.ft_search(search_query) if search_query.present?
      @total_count = @events.count
      @events = @events.limit(LIMIT)
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

  def typesense_enabled?
    Event.respond_to?(:typesense_search_events)
  end
end
