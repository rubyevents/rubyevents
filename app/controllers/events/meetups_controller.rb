class Events::MeetupsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /events/meetups
  def index
    @meetup_groups = EventSeries.meetup_groups.includes(:events).to_a.sort_by { |series| meetup_activity(series) }.reverse
    @upcoming_meetups_count = Event.where(kind: :meetup).upcoming.count
    @past_meetups_count = Event.where(kind: :meetup).past.count

    @groups_by_country = @meetup_groups
      .select { |series| series.country_code.present? }
      .group_by { |series| Country.find_by(country_code: series.country_code) }
      .except(nil)

    @countries_by_continent = @groups_by_country.keys
      .group_by(&:continent)
      .sort_by { |continent, _| continent&.name || "ZZ" }
      .to_h
  end

  private

  def meetup_activity(series)
    dates = series.meetups.map(&:start_date)
    upcoming = dates.select { |date| date >= Date.today }.min

    upcoming ? [1, -upcoming.jd] : [0, dates.max&.jd || 0]
  end
end
