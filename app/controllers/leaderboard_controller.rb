class LeaderboardController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]

  def index
    @filter = params[:filter]
    @year = params[:year]

    @ranked_speakers = User.speakers
      .left_joins(:talks)
      .group(:id)
      .order("COUNT(talks.id) DESC")
      .select("users.*, COUNT(talks.id) as talks_count_in_range")
      .where("users.name is not 'TODO'")
      .where(talks: {kind: %w[talk keynote]})

    if @year.present?
      @ranked_speakers = @ranked_speakers.where(talks: {date: Date.parse("#{@year}-01-01").all_year})
    elsif @filter == "last_12_months"
      @ranked_speakers = @ranked_speakers.where(talks: {date: 12.months.ago.to_date..Date.today})
    end

    @ranked_speakers = @ranked_speakers.limit(100)
  end
end
