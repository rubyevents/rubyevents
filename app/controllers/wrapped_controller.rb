class WrappedController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  YEAR = 2025

  def index
    @year = YEAR
    @year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @next_year = @year + 1
    @next_year_range = Date.new(@next_year, 1, 1)..Date.new(@next_year, 12, 31)

    @wrapped_cached_data = Rails.cache.fetch("wrapped:#{@year}:data", expires_in: 12.hours) do
      {
        talks_held: Talk.where(date: @year_range).distinct.count,
        talks_published: Talk.where(published_at: @year_range).distinct.count,
        total_conferences: Event.where(start_date: @year_range, kind: :conference).count,
        total_speakers: User.joins(:talks).where(talks: {date: @year_range}).distinct.count,
        total_hours: (Talk.where(published_at: @year_range).sum(:duration_in_seconds) / 3600.0).round,
        talks_with_slides: Talk.where(date: @year_range).where.not(slides_url: [nil, ""]).count,
        top_topics_slugs: top_topics_slugs,
        most_watched_events_slugs: most_watched_events.pluck(:slug),
        events_by_sessions_slugs: events_by_sessions.pluck(:slug),
        events_by_attendees_slugs: events_by_attendees.pluck(:slug),
        country_codes_with_events: country_codes_with_events,
        most_watched_talks_slugs: most_watched_talks_slugs,
        new_speakers: new_speakers,
        languages: languages,
        passports_issued: ConnectedAccount.passport.where(created_at: @year_range).count,
        unique_sponsors: unique_sponsors,
        event_participations: EventParticipation.joins(:event).where(events: {start_date: @year_range}).count,
        people_involved: people_involved,
        total_talks_watched: WatchedTalk.where(watched_at: @year_range).count,
        new_users: ConnectedAccount.github.where(created_at: @year_range).count,
        total_rubyists: User.count,
        rubyist_countries: rubyist_countries,
        total_visits: total_visits,
        total_page_views: total_page_views,
        next_year_conferences: Event.where(start_date: @next_year_range, kind: :conference).count,
        next_year_talks: Talk.where(date: @next_year_range).count,
        open_cfps: open_cfps,
        top_organizations_slugs: top_organizations_slugs
      }
    end

    # Leave this uncached, so users can make theirs public and see it on the /wrapped page immediately
    @public_users = User
      .with_public_wrapped
      .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
      .order(updated_at: :desc)
      .limit(100)
      .sample(35)

    @talks_held = @wrapped_cached_data[:talks_held]
    @talks_published = @wrapped_cached_data[:talks_published]
    @total_conferences = @wrapped_cached_data[:total_conferences]
    @total_speakers = @wrapped_cached_data[:total_speakers]
    @total_hours = @wrapped_cached_data[:total_hours]
    @talks_with_slides = @wrapped_cached_data[:talks_with_slides]

    @top_topics = Topic
      .where(slug: @wrapped_cached_data[:top_topics_slugs])
      .sort_by { |topic| @wrapped_cached_data[:top_topics_slugs].index(topic.slug) }

    @most_watched_events = Event
      .where(slug: @wrapped_cached_data[:most_watched_events_slugs])
      .sort_by { |event| @wrapped_cached_data[:most_watched_events_slugs].index(event.slug) }

    @events_by_sessions = events_by_sessions

    @events_by_attendees = events_by_attendees

    @countries_with_events = @wrapped_cached_data[:country_codes_with_events]
      .filter_map { |code| Country.find_by(country_code: code) }

    @most_watched_talks = Talk
      .where(slug: @wrapped_cached_data[:most_watched_talks_slugs])
      .includes(:speakers, :event)
      .sort_by { |talk| @wrapped_cached_data[:most_watched_talks_slugs].index(talk.slug) }

    @new_speakers = @wrapped_cached_data[:new_speakers]

    @languages = @wrapped_cached_data[:languages]

    @passports_issued = @wrapped_cached_data[:passports_issued]

    @unique_sponsors = @wrapped_cached_data[:unique_sponsors]

    @event_participations = @wrapped_cached_data[:event_participations]

    # @event_involvements = EventInvolvement
    # .joins(:event)
    # .where(events: {start_date: @year_range})
    # .count

    @people_involved = @wrapped_cached_data[:people_involved]

    @total_talks_watched = @wrapped_cached_data[:total_talks_watched]

    @new_users = @wrapped_cached_data[:new_users]

    @total_rubyists = @wrapped_cached_data[:total_rubyists]
    @github_contributors = 83

    @rubyist_countries = @wrapped_cached_data[:rubyist_countries]

    # @monthly_visits = Rollup
    #   .where(time: @year_range, interval: "month")
    #   .where(name: "ahoy_visits")
    #   .order(:time)
    #   .pluck(:time, :value)
    #   .map { |time, value| [time.strftime("%b"), value] }

    @total_visits = @wrapped_cached_data[:total_visits]

    @total_page_views = @wrapped_cached_data[:total_page_views]

    # next_year_events = Event.where(start_date: @next_year_range).count
    @next_year_conferences = @wrapped_cached_data[:next_year_conferences]
    @next_year_talks = @wrapped_cached_data[:next_year_talks]

    @open_cfps = @wrapped_cached_data[:open_cfps]

    @top_organizations = Organization.where(slug: @wrapped_cached_data[:top_organizations_slugs])
      .sort_by { |org| @wrapped_cached_data[:top_organizations_slugs].index(org.slug) }

    set_wrapped_meta_tags
  end

  private

  def set_wrapped_meta_tags
    title = "RubyEvents.org #{@year} Wrapped"
    description = "#{@year} in review. Explore the Ruby community's year!"
    image_url = view_context.image_url("og/wrapped-#{@year}.png")

    set_meta_tags(
      title: title,
      description: description,
      og: {
        title: title,
        description: description,
        image: image_url,
        type: "website",
        url: wrapped_url
      },
      twitter: {
        title: title,
        description: description,
        image: image_url,
        card: "summary_large_image"
      }
    )
  end

  def find_country_from_location(location_string)
    return nil if location_string.blank?

    country = Country.find(location_string)
    return country if country.present?

    location_string.split(",").each do |part|
      country = Country.find(part.strip)
      return country if country.present?
    end

    nil
  end

  def country_codes_with_events
    Event
      .where(start_date: @year_range)
      .where.not(country_code: nil)
      .distinct
      .pluck(:country_code)
  end

  def events_by_attendees
    events_by_attendees_source = @wrapped_cached_data&.dig(:events_by_attendees_slugs) ? Event.where(slug: @wrapped_cached_data[:events_by_attendees_slugs]) : Event
    @events_by_attendees = events_by_attendees_source
      .where(start_date: @year_range)
      .joins(:event_participations)
      .group(:id)
      .select("events.*, COUNT(event_participations.id) as attendees_count")
      .order("COUNT(event_participations.id) DESC")
      .limit(5)
  end

  def events_by_sessions
    events_by_sessions_source = @wrapped_cached_data&.dig(:events_by_sessions_slugs) ? Event.where(slug: @wrapped_cached_data[:events_by_sessions_slugs]) : Event
    @events_by_sessions = events_by_sessions_source
      .where(start_date: @year_range)
      .joins(:talks)
      .group(:id)
      .select("events.*, COUNT(talks.id) as talks_count")
      .order("COUNT(talks.id) DESC")
      .limit(5)
  end

  def languages
    Talk
      .where(date: @year_range)
      .where.not(language: nil)
      .group(:language)
      .count
      .sort_by { |_, count| -count }
      .map { |code, count| [Language.by_code(code) || code, count] }
  end

  def most_watched_events
    Event
      .where(start_date: @year_range)
      .joins(talks: :watched_talks)
      .group(:id)
      .order("COUNT(watched_talks.id) DESC")
      .limit(5)
  end

  def most_watched_talks_slugs
    Talk
      .joins(:watched_talks)
      .where(date: @year_range)
      .group(:id)
      .order("COUNT(watched_talks.id) DESC")
      .includes(:speakers, :event)
      .limit(10)
      .pluck(:slug)
  end

  def new_speakers
    User
      .joins(:talks)
      .where(talks: {date: @year_range})
      .where.not(id: User.joins(:talks).where(talks: {date: ...Date.new(@year, 1, 1)}).select(:id))
      .distinct
      .count
  end

  def open_cfps
    CFP
      .joins(:event)
      .where(events: {start_date: @next_year_range})
      .where("cfps.close_date IS NULL OR cfps.close_date >= ?", Date.new(@next_year, 1, 1))
      .where("cfps.open_date IS NULL OR cfps.open_date <= ?", Date.new(@next_year, 1, 1))
      .count
  end

  def people_involved
    EventInvolvement
      .joins(:event)
      .where(events: {start_date: @year_range})
      .where(involvementable_type: "User")
      .distinct
      .count(:involvementable_id)
  end

  def rubyist_countries
    User
      .where.not(location: [nil, ""])
      .distinct
      .pluck(:location)
      .filter_map { |location| find_country_from_location(location)&.alpha2 }
      .uniq
      .count
  end

  def top_organizations_slugs
    Organization
      .joins(:sponsors)
      .joins("INNER JOIN events ON sponsors.event_id = events.id")
      .where(events: {start_date: @year_range})
      .group("organizations.id")
      .order(Arel.sql("COUNT(DISTINCT events.id) DESC"))
      .limit(35)
      .pluck(:slug)
  end

  def top_topics_slugs
    Topic.approved
      .joins(:talks)
      .where(talks: {date: @year_range})
      .where.not("LOWER(topics.name) IN (?)", ["ruby", "ruby on rails", "lightning talks"])
      .group(:id)
      .order("COUNT(talks.id) DESC")
      .limit(5)
      .pluck(:slug)
  end

  def total_page_views
    Rollup
      .where(time: @year_range, interval: "month")
      .where(name: "ahoy_events")
      .sum(:value)
      .to_i
  end

  def total_visits
    Rollup
      .where(time: @year_range, interval: "month")
      .where(name: "ahoy_visits")
      .sum(:value)
      .to_i
  end

  def unique_sponsors
    Organization
      .joins(:sponsors)
      .joins("INNER JOIN events ON sponsors.event_id = events.id")
      .where(events: {start_date: @year_range})
      .distinct
      .count
  end
end
