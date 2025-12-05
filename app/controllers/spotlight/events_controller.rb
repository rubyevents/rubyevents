class Spotlight::EventsController < ApplicationController
  LIMIT = 15

  disable_analytics
  skip_before_action :authenticate_user!

  def index
    @events = Event.includes(:series).canonical.order(date: :desc)
    @events = @events.ft_search(search_query) if search_query.present?
    @events = @events.limit(LIMIT)

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  helper_method :search_query
  def search_query
    params[:s]
  end
end
