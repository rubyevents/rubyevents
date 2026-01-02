class WrappedController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  YEAR = 2025

  def index
    @year = YEAR
    year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @public_users = User
      .where(wrapped_public: true)
      .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
      .order(updated_at: :desc)
      .limit(100)
      .sample(35)

    @talks_held = Talk.where(date: year_range).distinct.count
    @talks_published = Talk.where(published_at: year_range).distinct.count
    @total_conferences = Event.where(start_date: year_range, kind: :conference).count
    @total_speakers = User.joins(:talks).where(talks: {date: year_range}).distinct.count
    @total_hours = (Talk.where(published_at: year_range).sum(:duration_in_seconds) / 3600.0).round
    @talks_with_slides = Talk.where(date: year_range).where.not(slides_url: [nil, ""]).count

    @top_topics = Topic.approved
      .joins(:talks)
      .where(talks: {date: year_range})
      .where.not("LOWER(topics.name) IN (?)", ["ruby", "ruby on rails", "lightning talks"])
      .group(:id)
      .order("COUNT(talks.id) DESC")
      .limit(5)

    @most_watched_events = Event
      .where(start_date: year_range)
      .joins(talks: :watched_talks)
      .group(:id)
      .order("COUNT(watched_talks.id) DESC")
      .limit(5)

    @events_by_sessions = Event
      .where(start_date: year_range)
      .joins(:talks)
      .group(:id)
      .select("events.*, COUNT(talks.id) as talks_count")
      .order("COUNT(talks.id) DESC")
      .limit(5)

    @events_by_attendees = Event
      .where(start_date: year_range)
      .joins(:event_participations)
      .group(:id)
      .select("events.*, COUNT(event_participations.id) as attendees_count")
      .order("COUNT(event_participations.id) DESC")
      .limit(5)

    @countries_with_events = Event
      .where(start_date: year_range)
      .where.not(country_code: nil)
      .distinct
      .pluck(:country_code)
      .map { |code| ISO3166::Country.new(code) }
      .compact

    @most_watched_talks = Talk
      .joins(:watched_talks)
      .where(date: year_range)
      .group(:id)
      .order("COUNT(watched_talks.id) DESC")
      .includes(:speakers, :event)
      .limit(10)

    @new_speakers = User
      .joins(:talks)
      .where(talks: {date: year_range})
      .where.not(id: User.joins(:talks).where(talks: {date: ...Date.new(@year, 1, 1)}).select(:id))
      .distinct
      .count

    @languages = Talk
      .where(date: year_range)
      .where.not(language: nil)
      .group(:language)
      .count
      .sort_by { |_, count| -count }
      .map { |code, count| [Language.by_code(code) || code, count] }

    @passports_issued = ConnectedAccount.passport.where(created_at: year_range).count

    @unique_sponsors = Organization
      .joins(:sponsors)
      .joins("INNER JOIN events ON sponsors.event_id = events.id")
      .where(events: {start_date: year_range})
      .distinct
      .count

    @event_participations = EventParticipation
      .joins(:event)
      .where(events: {start_date: year_range})
      .count

    @event_involvements = EventInvolvement
      .joins(:event)
      .where(events: {start_date: year_range})
      .count

    @people_involved = EventInvolvement
      .joins(:event)
      .where(events: {start_date: year_range})
      .where(involvementable_type: "User")
      .distinct
      .count(:involvementable_id)

    @total_talks_watched = WatchedTalk
      .where(created_at: year_range)
      .count

    @new_users = ConnectedAccount
      .github
      .where(created_at: year_range)
      .count

    @total_rubyists = User.count
    @github_contributors = 83

    rubyist_country_codes = Rails.cache.fetch("wrapped:#{@year}:rubyist_country_codes", expires_in: 1.hour) do
      User
        .where.not(location: [nil, ""])
        .distinct
        .pluck(:location)
        .filter_map { |location| find_country_from_location(location)&.alpha2 }
        .uniq
    end

    @rubyist_countries = rubyist_country_codes.map { |code| ISO3166::Country.new(code) }

    @monthly_visits = Rollup
      .where(time: year_range, interval: "month")
      .where(name: "ahoy_visits")
      .order(:time)
      .pluck(:time, :value)
      .map { |time, value| [time.strftime("%b"), value] }

    @total_visits = Rollup
      .where(time: year_range, interval: "month")
      .where(name: "ahoy_visits")
      .sum(:value)
      .to_i

    @total_page_views = Rollup
      .where(time: year_range, interval: "month")
      .where(name: "ahoy_events")
      .sum(:value)
      .to_i

    next_year = @year + 1
    next_year_range = Date.new(next_year, 1, 1)..Date.new(next_year, 12, 31)
    @next_year = next_year
    @next_year_events = Event.where(start_date: next_year_range).count
    @next_year_conferences = Event.where(start_date: next_year_range, kind: :conference).count
    @next_year_talks = Talk.where(date: next_year_range).count

    @open_cfps = CFP
      .joins(:event)
      .where(events: {start_date: next_year_range})
      .where("cfps.close_date IS NULL OR cfps.close_date >= ?", Date.new(next_year, 1, 1))
      .where("cfps.open_date IS NULL OR cfps.open_date <= ?", Date.new(next_year, 1, 1))
      .count

    @top_organizations = Organization
      .joins(:sponsors)
      .joins("INNER JOIN events ON sponsors.event_id = events.id")
      .where(events: {start_date: year_range})
      .group("organizations.id")
      .order(Arel.sql("COUNT(DISTINCT events.id) DESC"))
      .limit(35)

    set_wrapped_meta_tags
  end

  private

  def set_wrapped_meta_tags
    title = "RubyEvents.org #{@year} Wrapped"
    description = "#{@year} in review: #{ActionController::Base.helpers.number_with_delimiter(@talks_held)} talks held, #{ActionController::Base.helpers.number_with_delimiter(@total_conferences)} conferences, #{ActionController::Base.helpers.number_with_delimiter(@total_speakers)} speakers. Explore the Ruby community's year!"
    image_url = view_context.image_url("og/wrapped-2025.png")

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
end
