class Insights::CommunityController < ApplicationController
  skip_before_action :authenticate_user!

  EXCLUDED_SPEAKERS = %w[todo tbd tba].freeze

  def speaker_loyalty
    data = Rails.cache.fetch("insights:community:speaker_loyalty", expires_in: 6.hours) do
      loyal_speakers = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          u.id as speaker_id,
          u.name as speaker_name,
          u.slug as speaker_slug,
          es.name as series_name,
          es.slug as series_slug,
          COUNT(DISTINCT e.id) as event_count
        FROM users u
        JOIN user_talks ut ON u.id = ut.user_id
        JOIN talks t ON ut.talk_id = t.id
        JOIN events e ON t.event_id = e.id
        JOIN event_series es ON e.event_series_id = es.id
        WHERE ut.discarded_at IS NULL
          AND LOWER(u.name) NOT IN ('todo', 'tbd', 'tba')
        GROUP BY u.id, es.id
        HAVING event_count >= 3
        ORDER BY event_count DESC
        LIMIT 100
      SQL

      loyal_speakers.map do |row|
        {
          speaker_id: row["speaker_id"],
          speaker_name: row["speaker_name"],
          speaker_slug: row["speaker_slug"],
          series_name: row["series_name"],
          series_slug: row["series_slug"],
          appearances: row["event_count"]
        }
      end
    end

    render json: data
  end

  def most_connected
    data = Rails.cache.fetch("insights:community:most_connected", expires_in: 6.hours) do
      connections = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          u.id as speaker_id,
          u.name as speaker_name,
          u.slug as speaker_slug,
          COUNT(DISTINCT u2.id) as unique_co_speakers
        FROM users u
        JOIN user_talks ut ON u.id = ut.user_id
        JOIN talks t ON ut.talk_id = t.id
        JOIN talks t2 ON t.event_id = t2.event_id AND t.id != t2.id
        JOIN user_talks ut2 ON t2.id = ut2.talk_id AND ut2.user_id != u.id
        JOIN users u2 ON ut2.user_id = u2.id
        WHERE ut.discarded_at IS NULL
          AND ut2.discarded_at IS NULL
          AND LOWER(u.name) NOT IN ('todo', 'tbd', 'tba')
          AND LOWER(u2.name) NOT IN ('todo', 'tbd', 'tba')
        GROUP BY u.id
        ORDER BY unique_co_speakers DESC
        LIMIT 50
      SQL

      connections.map do |row|
        {
          id: row["speaker_id"],
          name: row["speaker_name"],
          slug: row["speaker_slug"],
          connections: row["unique_co_speakers"]
        }
      end
    end

    render json: data
  end

  def speaker_countries
    data = Rails.cache.fetch("insights:community:speaker_countries", expires_in: 1.hour) do
      User
        .speakers
        .where.not(country_code: [nil, ""])
        .where.not("LOWER(users.name) IN (?)", EXCLUDED_SPEAKERS)
        .group(:country_code)
        .count
        .map do |code, count|
          country = Country.find_by(country_code: code)
          {code: code, name: country&.name || code, count: count}
        end
        .sort_by { |d| -d[:count] }
    end

    render json: data
  end

  def international_events
    data = Rails.cache.fetch("insights:community:international_events", expires_in: 6.hours) do
      Event
        .joins(talks: :speakers)
        .where.not(events: {country_code: nil})
        .where.not(users: {country_code: nil})
        .where.not("LOWER(users.name) IN (?)", EXCLUDED_SPEAKERS)
        .group("events.id")
        .having("COUNT(DISTINCT users.id) >= 5")
        .order(Arel.sql("COUNT(CASE WHEN users.country_code != events.country_code THEN 1 END) * 100.0 / COUNT(DISTINCT users.id) DESC"))
        .limit(30)
        .pluck(
          Arel.sql("events.id, events.name, events.slug, events.country_code"),
          Arel.sql("COUNT(DISTINCT users.id)"),
          Arel.sql("COUNT(DISTINCT CASE WHEN users.country_code != events.country_code THEN users.id END)")
        )
        .map do |event_id, event_name, event_slug, event_country, total_speakers, international_speakers|
          {
            event_id: event_id,
            event_name: event_name,
            event_slug: event_slug,
            event_country: event_country,
            total_speakers: total_speakers,
            international_speakers: international_speakers,
            international_percentage: (international_speakers * 100.0 / total_speakers).round(1)
          }
        end
    end

    render json: data
  end

  def career_lengths
    data = Rails.cache.fetch("insights:community:career_lengths", expires_in: 6.hours) do
      careers = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          u.id,
          u.name,
          u.slug,
          MIN(strftime('%Y', t.date)) as first_year,
          MAX(strftime('%Y', t.date)) as last_year,
          COUNT(DISTINCT t.id) as talk_count
        FROM users u
        JOIN user_talks ut ON u.id = ut.user_id
        JOIN talks t ON ut.talk_id = t.id
        WHERE ut.discarded_at IS NULL
          AND t.date IS NOT NULL
          AND LOWER(u.name) NOT IN ('todo', 'tbd', 'tba')
        GROUP BY u.id
        HAVING talk_count >= 3
        ORDER BY (CAST(MAX(strftime('%Y', t.date)) AS INTEGER) - CAST(MIN(strftime('%Y', t.date)) AS INTEGER)) DESC, talk_count DESC
        LIMIT 50
      SQL

      careers.map do |row|
        first = row["first_year"].to_i
        last = row["last_year"].to_i
        {
          id: row["id"],
          name: row["name"],
          slug: row["slug"],
          first_year: first,
          last_year: last,
          career_years: last - first + 1,
          talk_count: row["talk_count"]
        }
      end
    end

    render json: data
  end

  def series_longevity
    data = Rails.cache.fetch("insights:community:series_longevity", expires_in: 1.hour) do
      EventSeries
        .joins(:events)
        .where.not(events: {start_date: nil})
        .group("event_series.id")
        .having("COUNT(events.id) >= 2")
        .order(Arel.sql("CAST(MAX(strftime('%Y', events.start_date)) AS INTEGER) - CAST(MIN(strftime('%Y', events.start_date)) AS INTEGER) DESC"))
        .limit(30)
        .pluck(
          Arel.sql("event_series.id, event_series.name, event_series.slug"),
          Arel.sql("MIN(strftime('%Y', events.start_date))"),
          Arel.sql("MAX(strftime('%Y', events.start_date))"),
          Arel.sql("COUNT(events.id)")
        )
        .map do |id, name, slug, first_year, last_year, event_count|
          {
            id: id,
            name: name,
            slug: slug,
            first_year: first_year.to_i,
            last_year: last_year.to_i,
            years_running: last_year.to_i - first_year.to_i + 1,
            event_count: event_count
          }
        end
    end

    render json: data
  end

  def topic_emergence
    data = Rails.cache.fetch("insights:community:topic_emergence", expires_in: 6.hours) do
      Topic.approved
        .joins(talk_topics: :talk)
        .where.not(talks: {date: nil})
        .group("topics.id")
        .having("COUNT(DISTINCT talks.id) >= 10")
        .order(Arel.sql("MIN(strftime('%Y', talks.date))"))
        .limit(50)
        .pluck(
          Arel.sql("topics.id, topics.name, topics.slug"),
          Arel.sql("MIN(strftime('%Y', talks.date))"),
          Arel.sql("MAX(strftime('%Y', talks.date))"),
          Arel.sql("COUNT(DISTINCT talks.id)")
        )
        .map do |id, name, slug, first_year, last_year, talk_count|
          {
            id: id,
            name: name,
            slug: slug,
            first_year: first_year.to_i,
            last_year: last_year.to_i,
            years_active: last_year.to_i - first_year.to_i + 1,
            talk_count: talk_count
          }
        end
    end

    render json: data
  end
end
