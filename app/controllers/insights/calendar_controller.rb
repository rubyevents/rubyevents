class Insights::CalendarController < ApplicationController
  skip_before_action :authenticate_user!

  def monthly_distribution
    data = Rails.cache.fetch("insights:calendar:monthly", expires_in: 1.hour) do
      month_names = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]

      Event
        .where.not(start_date: nil)
        .group(Arel.sql("strftime('%m', start_date)"))
        .count
        .map do |month_num, count|
          month_idx = month_num.to_i - 1
          {month: month_num, name: month_names[month_idx], count: count}
        end
        .sort_by { |d| d[:month].to_i }
    end

    render json: data
  end

  def heatmap
    data = Rails.cache.fetch("insights:calendar:heatmap", expires_in: 1.hour) do
      Event
        .where.not(start_date: nil)
        .group(Arel.sql("strftime('%Y', start_date)"), Arel.sql("strftime('%m', start_date)"))
        .count
        .map do |(year, month), count|
          {year: year, month: month.to_i, count: count}
        end
        .sort_by { |d| [d[:year], d[:month]] }
    end

    render json: data
  end

  def speaker_debuts
    data = Rails.cache.fetch("insights:calendar:speaker_debuts", expires_in: 6.hours) do
      first_talks = Talk
        .joins(:speakers)
        .where.not(date: nil)
        .where.not("LOWER(users.name) IN (?)", %w[todo tbd tba])
        .group("users.id")
        .pluck(Arel.sql("users.id, MIN(strftime('%Y', talks.date))"))

      debuts_by_year = first_talks.group_by { |_, year| year }.transform_values(&:count)

      debuts_by_year
        .sort_by { |year, _| year.to_i }
        .map { |year, count| {year: year, count: count} }
    end

    render json: data
  end

  def first_time_speakers
    data = Rails.cache.fetch("insights:calendar:first_time_speakers", expires_in: 6.hours) do
      excluded = %w[todo tbd tba]

      speaker_years = Talk
        .joins(:speakers)
        .where.not(date: nil)
        .where.not("LOWER(users.name) IN (?)", excluded)
        .pluck(Arel.sql("users.id, strftime('%Y', talks.date)"))

      speaker_first_year = {}

      speaker_years.each do |speaker_id, year|
        if speaker_first_year[speaker_id].nil? || year < speaker_first_year[speaker_id]
          speaker_first_year[speaker_id] = year
        end
      end

      year_stats = Hash.new { |h, k| h[k] = {total: Set.new, first_time: 0} }

      speaker_years.each do |speaker_id, year|
        year_stats[year][:total] << speaker_id
        year_stats[year][:first_time] += 1 if speaker_first_year[speaker_id] == year
      end

      year_stats
        .sort_by { |year, _| year.to_i }
        .map do |year, stats|
          total = stats[:total].size
          first_time = stats[:first_time]
          {
            year: year,
            total_speakers: total,
            first_time_speakers: first_time,
            first_time_percentage: (total > 0) ? (first_time * 100.0 / total).round(1) : 0
          }
        end
    end

    render json: data
  end

  def day_of_week
    data = Rails.cache.fetch("insights:calendar:day_of_week", expires_in: 1.hour) do
      day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

      Event
        .where.not(start_date: nil)
        .group(Arel.sql("strftime('%w', start_date)"))
        .count
        .map do |day_num, count|
          {day: day_num.to_i, name: day_names[day_num.to_i], count: count}
        end
        .sort_by { |d| d[:day] }
    end

    render json: data
  end
end
