class WatchedTalksController < ApplicationController
  include ActionView::RecordIdentifier
  include WatchedTalks

  def index
    @watched_talks = Current.user.watched_talks
      .includes(talk: [:speakers, {event: :series}, {child_talks: :speakers}])
      .order(created_at: :desc)

    @talks = @watched_talks.map(&:talk)
    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end

  def destroy
    @watched_talk = Current.user.watched_talks.find(params[:id])
    @watched_talk.delete

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(dom_id(@watched_talk.talk, :card_horizontal))
      end
      format.html { redirect_to watched_talks_path, notice: "Video removed from watched list" }
    end
  end
end
