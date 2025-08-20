class WatchedTalksController < ApplicationController
  def index
    @talks = Current.user.watched_talks
      .includes(talk: [:speakers, {event: :organisation}, {child_talks: :speakers}])
      .order(created_at: :desc)
  end
end
