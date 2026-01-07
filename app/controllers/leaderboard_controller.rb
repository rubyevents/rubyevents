class LeaderboardController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @filter = params[:filter] || "all_time"
    @ranked_speakers = User.speakers
      .left_joins(:talks)
      .group(:id)
      .order("COUNT(talks.id) DESC")
      .select("users.*, COUNT(talks.id) as talks_count_in_range") 
      .where("users.name is not 'TODO'")

    if @filter == "last_12_months"
      @ranked_speakers = @ranked_speakers.where("talks.date >= ?", 12.months.ago.to_date)
    end
    @ranked_speakers = @ranked_speakers.limit(100)
  end
end
