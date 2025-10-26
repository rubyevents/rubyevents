class RecommendationsController < ApplicationController
  include WatchedTalks

  def index
    @recommended_talks = Current.user.talk_recommender.talks(limit: 64) if Current.user
    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
