class Talks::WatchedTalksController < ApplicationController
  include ActionView::RecordIdentifier
  include WatchedTalks
  include RemoteModal

  respond_with_remote_modal only: [:new]

  before_action :set_talk
  after_action :broadcast_update_to_event_talks, only: [:create, :destroy, :update]

  def new
    @watched_talk = @talk.watched_talks.find_or_initialize_by(user: Current.user)
    set_modal_options(size: :lg)
  end

  def create
    @watched_talk = @talk.watched_talks.find_or_initialize_by(user: Current.user)
    @watched_talk.assign_attributes(watched_talk_params.merge(watched: true))
    @watched_talk.save!

    respond_to do |format|
      format.html { redirect_back fallback_location: @talk }
      format.turbo_stream
    end
  end

  def destroy
    @talk.unmark_as_watched!

    respond_to do |format|
      format.html { redirect_back fallback_location: @talk }
      format.turbo_stream
    end
  end

  def toggle_attendance
    @watched_talk = @talk.watched_talks.find_by(user: Current.user)

    if @watched_talk&.watched_on == "in_person"
      @watched_talk.destroy!
      @attended = false
    else
      @watched_talk&.destroy! # Remove existing non-in-person record if any
      @talk.watched_talks.create!(
        user: Current.user,
        watched: true,
        watched_on: "in_person",
        watched_at: @talk.date
      )
      @attended = true
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: event_path(@talk.event) }
      format.turbo_stream
    end
  end

  def update
    @watched_talk = @talk.watched_talks.find_or_create_by!(user: Current.user)
    @auto_marked = false

    updates = watched_talk_params
    is_feedback_update = updates.keys.any? { |k| k.in?(%w[feeling experience_level content_freshness] + WatchedTalk::FEEDBACK_QUESTIONS.keys.map(&:to_s)) }
    is_watched_on_update = updates.key?(:watched_on)

    if is_feedback_update
      updates = updates.merge(watched: true, feedback_shared_at: Time.current)
    end

    if !@watched_talk.watched? && should_auto_mark?(updates[:progress_seconds])
      updates = updates.merge(watched: true, watched_on: "rubyevents")
      @auto_marked = true
    end

    @watched_talk.update!(updates)
    @form_open = is_feedback_update
    @should_stream = @auto_marked || is_feedback_update || is_watched_on_update

    respond_to do |format|
      format.html { redirect_back fallback_location: @talk }
      format.turbo_stream do
        if @should_stream
          render :update
        else
          head :no_content
        end
      end
    end
  end

  private

  def watched_talk_params
    params.fetch(:watched_talk, {}).permit(
      :progress_seconds,
      :watched_on,
      :watched_at,
      :feeling,
      :experience_level,
      :content_freshness,
      *WatchedTalk::FEEDBACK_QUESTIONS.keys
    )
  end

  def set_talk
    @talk = Talk.includes(event: :series).find_by(slug: params[:talk_slug])
  end

  def should_auto_mark?(progress_seconds)
    return false unless progress_seconds.present?
    return false unless @talk.duration_in_seconds.to_i > 0

    progress_percentage = (progress_seconds.to_f / @talk.duration_in_seconds) * 100
    progress_percentage >= 90
  end

  def broadcast_update_to_event_talks
    Turbo::StreamsChannel.broadcast_replace_to [@talk.event, :talks],
      target: dom_id(@talk, :card_horizontal),
      partial: "talks/card_horizontal",
      method: :replace,
      locals: {compact: true,
               talk: @talk,
               current_talk: @talk,
               turbo_frame: "talk",
               user_watched_talks: user_watched_talks}
  end
end
