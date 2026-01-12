class Analytics::DashboardsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :admin_required, only: %i[top_referrers top_landing_pages top_searches]

  def daily_visits
    @daily_visits = Rollup.where(time: 60.days.ago.to_date..Date.yesterday.end_of_day).series("ahoy_visits", interval: :day)
  end

  def daily_page_views
    @daily_page_views = Rollup.where(time: 60.days.ago.to_date..Date.yesterday.end_of_day).series("ahoy_events", interval: :day)
  end

  def monthly_visits
    @monthly_visits = Rollup.where(time: 12.months.ago.to_date.beginning_of_month..Date.yesterday.end_of_day).series("ahoy_visits", interval: :month)
  end

  def monthly_page_views
    @monthly_page_views = Rollup.where(time: 12.months.ago.to_date.beginning_of_month..Date.yesterday.end_of_day).series("ahoy_events", interval: :month)
  end

  def yearly_conferences
    # 1. Might be inefficient, but it's a first step. Note that Rollup class doesn't seem to contain
    #   conferences at the moment. To optimize this code, we probably want to add yearly info to the Rollup class.
    # 2. Note that some years are integers and some are strings. We should probably convert them all to either format in import.
    #   (to reproduce, remove the `.to_s` in the map below)
    @yearly_conferences = Event.all.select(&:conference?).select { |event| event.start_date.present? || event.static_metadata.year.present? }.group_by { |event| event.start_date&.year || event.static_metadata.year.to_i }.map { |year, events| [year.to_s, events.count] }.sort
  end

  def yearly_talks
    @yearly_talks = Rollup.series("talks", interval: :year).map { |date, count| [date.year.to_s, count] }.sort
  end

  def top_referrers
    @top_referrers = Rails.cache.fetch("top_referrers", expires_at: Time.current.end_of_day) do
      Ahoy::Visit
        .where("date(started_at) BETWEEN ? AND ?", 60.days.ago.to_date, Date.yesterday)
        .where.not(referring_domain: [nil, "", "rubyvideo.dev", "www.rubyvideo.dev", "rubyevents.org", "www.rubyevents.org"])
        .group(:referring_domain)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)
        .count
    end
  end

  def top_landing_pages
    @top_landing_pages = Rails.cache.fetch("top_landing_pages", expires_at: Time.current.end_of_day) do
      Ahoy::Visit
        .where("date(started_at) BETWEEN ? AND ?", 60.days.ago.to_date, Date.yesterday)
        .where.not(landing_page: [nil, ""])
        .group(:landing_page)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(20)
        .count
        .map do |landing_page, count|
        uri = URI.parse(landing_page)
        [uri.path, count]
      end
        .group_by { |path, _| path }
        .transform_values { |entries| entries.sum { |_, count| count } }
        .to_a
        .sort_by { |_, count| -count }
        .first(10)
    end
  end

  def top_searches
    @top_searches = Rails.cache.fetch("top_searches", expires_at: Time.current.end_of_day) do
      Ahoy::Event
        .where("date(time) BETWEEN ? AND ?", 60.days.ago.to_date, Time.current)
        .where(name: "talks#index")
        .where("json_extract(properties, '$.s') IS NOT NULL")   # Filter out NULL values in SQL
        .where("trim(json_extract(properties, '$.s')) != ''")   # Filter out empty strings in SQL
        .group("json_extract(properties, '$.s')")               # Group by the search term
        .order(Arel.sql("COUNT(*) DESC"))                       # Order by count
        .limit(10)
        .pluck(Arel.sql("json_extract(properties, '$.s'), COUNT(*)"))  # Get search term and count
        .to_h
    end
  end

  private

  def admin_required
    redirect_to analytics_dashboards_path unless Current.user&.admin?
  end
end
