class WatchedTalksController < ApplicationController
  include WatchedTalks

  def index
    @talks = Current.user.watched_talks
      .includes(talk: [:speakers, {event: :organisation}, {child_talks: :speakers}])
      .order(created_at: :desc)
      .map(&:talk)
  end
end
