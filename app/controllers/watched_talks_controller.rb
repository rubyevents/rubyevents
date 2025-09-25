class WatchedTalksController < ApplicationController
  include WatchedTalks

  def index
    @watched_talks = Current.user.watched_talks
      .includes(talk: [:speakers, {event: :organisation}, {child_talks: :speakers}])
      .order(created_at: :desc)
    @talks = @watched_talks.map(&:talk)
    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
