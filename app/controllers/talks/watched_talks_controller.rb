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

  def update
    @watched_talk = @talk.watched_talks.find_or_create_by!(user: Current.user)

    updates = watched_talk_params
    is_feedback_update = updates.keys.any? { |k| k.in?(%w[feeling] + WatchedTalk::FEEDBACK_QUESTIONS.keys.map(&:to_s)) }

    if is_feedback_update
      updates = updates.merge(watched: true, feedback_shared_at: Time.current)
    end

    @watched_talk.update!(updates)
    @form_open = is_feedback_update

    respond_to do |format|
      format.html { redirect_back fallback_location: @talk }
      format.turbo_stream
    end
  end

  private

  def watched_talk_params
    params.fetch(:watched_talk, {}).permit(
      :progress_seconds,
      :watched_on,
      :watched_at,
      :feeling,
      *WatchedTalk::FEEDBACK_QUESTIONS.keys
    )
  end

  def set_talk
    @talk = Talk.includes(event: :series).find_by(slug: params[:talk_slug])
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
