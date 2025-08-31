class LeaderboardController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @filter = params[:filter] || "all_time"
    @ranked_speakers = User.speakers
      .group(:id)
      .order("COUNT(talks.id) DESC")
      .select("speakers.name, speakers.github, speakers.id, speakers.slug, speakers.updated_at, speakers.bsky_metadata, speakers.github_metadata, COUNT(talks.id) as talks_count")
      .where("speakers.name is not 'TODO'")

    if @filter == "last_12_months"
      @ranked_speakers = @ranked_speakers.where("talks.date >= ?", 12.months.ago.to_date)
    end
    @ranked_speakers = @ranked_speakers.limit(100)
  end
end
