# frozen_string_literal: true

module Talk::Queries
  extend ActiveSupport::Concern

  class_methods do
    def newest_talks = watchable.where("date <= ?", Date.current).order(date: :desc)
    def recently_published_talks = watchable.where.not(published_at: nil).order(published_at: :desc)
    def trending_talks = watchable.joins(:watched_talks).where(watched_talks: {watched_at: 30.days.ago..}).group(:id).order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def popular_talks = watchable.joins(:watched_talks).group(:id).order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def popular_on_youtube_talks = watchable.where("view_count > 0").order(view_count: :desc)
    def most_bookmarked_talks = watchable.joins(:watch_list_talks).group(:id).order(Arel.sql("COUNT(watch_list_talks.id) DESC"))
    def hidden_gems_talks = watchable.joins(:watched_talks).where("view_count < 5000 OR view_count IS NULL").group(:id).having("COUNT(watched_talks.id) >= 3").order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def quick_watches_talks = watchable.where("duration_in_seconds > 0 AND duration_in_seconds <= ?", 15 * 60)
    def deep_dives_talks = watchable.where("duration_in_seconds >= ?", 45 * 60)
    def evergreen_talks = watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.content_freshness') = ?", "evergreen").group(:id).having("COUNT(watched_talks.id) >= 2").order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def beginner_friendly_talks = watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.experience_level') = ?", "beginner").group(:id).having("COUNT(watched_talks.id) >= 2").order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def most_liked_talks = watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.liked') = ?", true).group(:id).having("COUNT(watched_talks.id) >= 2").order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def mind_blowing_talks = watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.feeling') = ?", "mind_blown").group(:id).having("COUNT(watched_talks.id) >= 2").order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def inspiring_talks = watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.feeling') IN (?, ?)", "inspired", "exciting").or(watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.inspiring') = ?", true)).group(:id).having("COUNT(watched_talks.id) >= 2").order(Arel.sql("COUNT(watched_talks.id) DESC"))
    def recommended_by_community_talks = watchable.joins(:watched_talks).where("json_extract(watched_talks.feedback, '$.would_recommend') = ?", true).group(:id).having("COUNT(watched_talks.id) >= 2").order(Arel.sql("COUNT(watched_talks.id) DESC"))
  end
end
