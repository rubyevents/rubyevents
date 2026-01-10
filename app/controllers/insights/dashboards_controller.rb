class Insights::DashboardsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @stats = Rails.cache.fetch("insights:dashboard:stats", expires_in: 1.hour) do
      {
        total_events: Event.count,
        total_talks: Talk.count,
        total_speakers: User.speakers.count,
        total_topics: Topic.approved.count,
        total_countries: Event.where.not(country_code: nil).distinct.pluck(:country_code).count
      }
    end
  end
end
