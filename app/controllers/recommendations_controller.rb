class RecommendationsController < ApplicationController
  include Pagy::Backend
  include WatchedTalks

  def index
    if Current.user
      talks = Current.user.talk_recommender.talks(limit: 100)
      @pagy, @recommended_talks = pagy_array(talks, limit: 42)
    end

    @user_favorite_talks_ids = Current.user&.default_watch_list&.talks&.ids || []
  end
end
