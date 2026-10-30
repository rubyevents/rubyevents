class Events::SeriesController < ApplicationController
  include Pagy::Backend

  skip_before_action :authenticate_user!, only: %i[index show events]
  before_action :set_event_series, only: %i[show events reimport reindex]
  before_action :require_admin!, only: %i[reimport reindex]

  # GET /events/series
  def index
    @event_series = EventSeries.includes(:events).order(:name)
  end

  # GET /events/series/:slug
  def show
    set_meta_tags(@event_series)
    @subscription = Current.user&.event_series_subscriptions&.find_by(event_series: @event_series)

    @events = @event_series.events.sort_by { |event|
      begin
        event.start_date || Date.today
      rescue
        Date.today
      end
    }.reverse

    @todos = @event_series.todos
    @child_series = @event_series.children.includes(:events).order(:name)
    @organizers = @event_series.event_involvements.includes(:involvementable).order(:role, :position)
    @series_sponsors = @event_series.sponsors.includes(:organization).order(:level)
    @series_cfps = @event_series.cfps.open

    load_meetups if @event_series.meetup?
    @other_events = @upcoming_meetups ? @events.reject { |event| event.meetup? && event.start_date.present? } : @events

    render :meetup_group if @upcoming_meetups
  end

  # GET /events/series/:slug/events
  def events
    return redirect_to(series_path(@event_series)) if @event_series.meetups.none?

    @all_past_meetups = true
    show
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

  def load_meetups
    meetups = Event.where(id: @event_series.meetups.map(&:id)).includes(:series, talks: :speakers).order(start_date: :desc).to_a

    @upcoming_meetups = meetups.select(&:upcoming?).reverse
    @past_meetups = meetups.reject(&:upcoming?)

    @meetups_view = "past" if @all_past_meetups
    @meetups_view ||= params[:view].presence_in(%w[upcoming past]) || (@upcoming_meetups.any? ? "upcoming" : "past")
    speaker_counts = meetups.flat_map(&:talks).flat_map { |talk| talk.speakers.reject { |speaker| speaker.name == "TODO" }.map(&:id) }.tally

    @meetup_speakers = User.preloaded.where(id: speaker_counts.keys).where("talks_count > 0").to_a
      .sort_by { |speaker| [-speaker_counts[speaker.id], speaker.name] }
      .first(24)

    @meetup_talk_counts = speaker_counts

    talks = meetups.flat_map(&:talks)
    @recent_recordings = talks.select(&:published?).sort_by { |talk| talk.date || Date.new(1900) }.last(6).reverse

    @meetup_stats = {
      "meetups" => meetups.size,
      "talks" => talks.size,
      "speakers" => speaker_counts.size,
      "since" => meetups.map(&:start_date).min&.year
    }
  end

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
