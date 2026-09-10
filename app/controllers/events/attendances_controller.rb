class Events::AttendancesController < ApplicationController
  include WatchedTalks

  before_action :set_event, only: [:show]

  def index
    @events = Current.user.participated_events
      .includes(:series, :top_level_talks)
      .where.not(end_date: nil)
      .where(end_date: ..Date.today)
      .distinct
      .order(start_date: :desc)

    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }

    event_ids = @events.pluck(:id)
    # Attendance UI only lists top-level talks (not nested lightning/child talks),
    # so counts must use the same scope everywhere.
    watched_talks = Current.user.watched_talks
      .joins(:talk)
      .merge(Talk.top_level)
      .where(talks: {event_id: event_ids})
      .pluck("talks.event_id", :watched_on)

    @attendance_stats = Hash.new { |h, k| h[k] = {in_person: 0, online: 0} }

    watched_talks.each do |event_id, watched_on|
      if watched_on == "in_person"
        @attendance_stats[event_id][:in_person] += 1
      else
        @attendance_stats[event_id][:online] += 1
      end
    end
  end

  def show
    event_is_past = @event.end_date.present? && @event.end_date < Date.today
    @participation = Current.user.main_participation_to(@event)

    unless @participation.present? && event_is_past && @event.top_level_talks.any?
      redirect_to event_path(@event), alert: "You can only mark attendance for past events you participated in"
      return
    end

    @attendance_talks = @event.talks_in_running_order(child_talks: false).includes(:speakers).to_a
    attendance_talk_ids = @attendance_talks.map(&:id)

    user_watched_talks = Current.user.watched_talks.where(talk_id: attendance_talk_ids)
    watched_talks_data = user_watched_talks.pluck(:talk_id, :watched_on)
    @user_in_person_talk_ids = watched_talks_data.select { |_, on| on == "in_person" }.map(&:first).to_set
    @user_online_talk_ids = watched_talks_data.reject { |_, on| on == "in_person" }.map(&:first).to_set
    @user_feedback_talk_ids = user_watched_talks.select(&:has_rating_feedback?).map(&:talk_id).to_set
    @attendance_days = @event.schedule.exist? ? @event.schedule.days : []
    @attendance_tracks = @event.schedule.exist? ? @event.schedule.tracks : []
  end

  private

  def set_event
    @event = Event.includes(:series).find_by(slug: params[:event_slug])
    redirect_to events_attendances_path, alert: "Event not found" unless @event
  end
end
