class Events::SeriesController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :set_event_series, only: %i[show reimport reindex]
  before_action :require_admin!, only: %i[reimport reindex]

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

  # POST /events/series/:slug/reimport
  def reimport
    static_series = Static::EventSeries.find_by_slug(@event_series.slug)

    if static_series
      static_series.import!
      redirect_to series_path(@event_series), notice: "Event series reimported successfully."
    else
      redirect_to series_path(@event_series), alert: "Static event series not found."
    end
  end

  # POST /events/series/:slug/reindex
  def reindex
    Search::Backend.index(@event_series)

    @event_series.events.find_each do |event|
      Search::Backend.index(event)

      event.talks.find_each { |talk| Search::Backend.index(talk) }
    end

    redirect_to series_path(@event_series), notice: "Event series reindexed successfully."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event_series
    @event_series = EventSeries.includes(:events).find_by(slug: params[:slug])
    @event_series ||= EventSeries.find_by_slug_or_alias(params[:slug])

    return redirect_to(root_path, status: :moved_permanently) unless @event_series

    redirect_to series_path(@event_series), status: :moved_permanently if @event_series.slug != params[:slug]
  end

  def require_admin!
    redirect_to series_path(@event_series), alert: "Not authorized" unless Current.user&.admin?
  end
end
