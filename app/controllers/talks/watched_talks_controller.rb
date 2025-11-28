class Talks::WatchedTalksController < ApplicationController
  include ActionView::RecordIdentifier
  include WatchedTalks

  before_action :set_talk
  after_action :broadcast_update_to_event_talks

  def create
    @talk.mark_as_watched!

    redirect_back fallback_location: @talk
  end

  def destroy
    @talk.unmark_as_watched!

    redirect_back fallback_location: @talk
  end

  def update
    @talk.watched_talks.find_or_create_by!(user: Current.user).update!(watched_talk_params)

    head :ok
  end

  private

  def watched_talk_params
    params.require(:watched_talk).permit(:progress_seconds)
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
