class EventsController < ApplicationController
  include WatchedTalks
  include Pagy::Backend
  skip_before_action :authenticate_user!, only: %i[index show update]
  before_action :set_event, only: %i[show edit update]
  before_action :set_user_favorites, only: %i[show]

  # GET /events
  def index
    @events = Event.includes(:organisation, :keynote_speakers)
      .conference
      .where(end_date: Date.today..)
      .order(start_date: :asc)
  end

  # GET /events/1
  def show
    set_meta_tags(@event)

    if @event.meetup?
      all_meetup_events = @event.talks.where(meta_talk: true).includes(:speakers, :parent_talk, child_talks: :speakers)
      @upcoming_meetup_events = all_meetup_events.where("date >= ?", Date.today).order(date: :asc).limit(4)
      @recent_meetup_events = all_meetup_events.where("date < ?", Date.today).order(date: :desc).limit(4)
      @recent_talks = @event.talks.where(meta_talk: false).includes(:speakers, :parent_talk, child_talks: :speakers).order(date: :desc).to_a.sample(8)
      @featured_speakers = @event.speakers.joins(:talks).distinct.to_a.sample(8)
    else
      @keynotes = @event.talks.joins(:speakers).where(kind: "keynote").includes(:speakers, event: :organisation)
      @recent_talks = @event.talks.watchable.includes(:speakers, event: :organisation).limit(8).shuffle
      keynote_speakers = @event.speakers.joins(:talks).where(talks: {kind: "keynote"}).distinct
      other_speakers = @event.speakers.joins(:talks).where.not(talks: {kind: "keynote"}).distinct.limit(8)
      @featured_speakers = (keynote_speakers + other_speakers.first(8 - keynote_speakers.size)).uniq.shuffle
    end

    @sponsors = @event.event_sponsors.includes(:sponsor).joins(:sponsor).shuffle
  end

  # GET /events/1/edit
  def edit
  end

  # PATCH/PUT /events/1
  def update
    suggestion = @event.create_suggestion_from(params: event_params, user: Current.user)

    if suggestion.persisted?
      redirect_to event_path(@event), notice: suggestion.notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event
    @event = Event.includes(:organisation).find_by!(slug: params[:slug])
    redirect_to event_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
  end

  # Only allow a list of trusted parameters through.
  def event_params
    params.require(:event).permit(:name, :city, :country_code)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
