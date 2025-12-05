class Events::SeriesController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :set_event_series, only: %i[show]

  # GET /events/series
  def index
    @event_series = EventSeries.includes(:events).order(:name)
  end

  # GET /events/series/:slug
  def show
    set_meta_tags(@event_series)

    @events = @event_series.events.sort_by { |event|
      begin
        event.start_date || Date.today
      rescue
        Date.today
      end
    }.reverse
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event_series
    @event_series = EventSeries.includes(:events).find_by(slug: params[:slug])
    @event_series ||= EventSeries.find_by_slug_or_alias(params[:slug])

    return redirect_to(root_path, status: :moved_permanently) unless @event_series

    redirect_to series_path(@event_series), status: :moved_permanently if @event_series.slug != params[:slug]
  end
end
