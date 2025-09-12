class WatchedTalksController < ApplicationController
  include WatchedTalks

  def index
    @watched_talks = Current.user.watched_talks
      .includes(talk: [:speakers, {event: :organisation}, {child_talks: :speakers}])
      .order(created_at: :desc)
    @talks = @watched_talks.map(&:talk)
  end
end
