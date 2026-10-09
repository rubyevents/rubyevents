class FeedbackController < ApplicationController
  include WatchedTalks

  def index
    @filter = params[:filter] || "all"

    watched_includes = {talk: [:speakers, {event: :series}, {child_talks: :speakers}]}

    @rated_talks = Current.user.watched_talks
      .watched
      .where("json_extract(feedback, '$.feeling') IS NOT NULL")
      .includes(**watched_includes)
      .order(watched_at: :desc)

    @unrated_talks = Current.user.watched_talks
      .watched
      .where("json_extract(feedback, '$.feeling') IS NULL")
      .includes(**watched_includes)
      .order(watched_at: :desc)
  end
end
