class Insights::EventsController < ApplicationController
  skip_before_action :authenticate_user!

  def timeline
    data = Rails.cache.fetch("insights:events:timeline", expires_in: 1.hour) do
      events_by_year_and_kind = Event
        .where.not(start_date: nil)
        .group(Arel.sql("strftime('%Y', start_date)"), :kind)
        .count

      years = events_by_year_and_kind.keys.map(&:first).uniq.compact.sort
      kinds = Event.kinds.keys

      years.map do |year|
        row = {year: year}
        kinds.each do |kind|
          row[kind] = events_by_year_and_kind[[year, kind]] || 0
        end
        row
      end
    end

    render json: data
  end

  def by_kind
    data = Rails.cache.fetch("insights:events:by_kind", expires_in: 1.hour) do
      Event.group(:kind).count.map do |kind, count|
        {kind: kind, count: count, label: kind.to_s.titleize}
      end
    end

    render json: data
  end

  def by_country
    data = Rails.cache.fetch("insights:events:by_country", expires_in: 1.hour) do
      Event
        .where.not(country_code: nil)
        .group(:country_code)
        .count
        .map do |code, count|
          country = Country.find_by(country_code: code)
          {
            country_code: code,
            country_name: country&.name || code,
            count: count
          }
        end
        .sort_by { |c| -c[:count] }
    end

    render json: data
  end
end
