class LeaderboardController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @filter = params[:filter] || "all_time"
    @ranked_speakers = User.speakers
      .left_joins(:talks)
      .group(:id)
      .order("COUNT(talks.id) DESC")
      .select("users.name, users.github_handle, users.id, users.slug, users.updated_at, users.bsky_metadata, users.github_metadata, COUNT(talks.id) as talks_count")
      .where("users.name is not 'TODO'")

    if @filter == "last_12_months"
      @ranked_speakers = @ranked_speakers.where("talks.date >= ?", 12.months.ago.to_date)
    end
    @ranked_speakers = @ranked_speakers.limit(100)
  end
end
