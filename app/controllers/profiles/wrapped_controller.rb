class Profiles::WrappedController < ApplicationController
  include ProfileData
  include EventMapMarkers

  YEAR = 2025

  before_action :check_wrapped_access, only: [:index, :card, :og_image]
  before_action :require_owner, only: [:toggle_visibility, :generate_card]

  def index
    @year = YEAR
    @is_owner = @user == Current.user
    year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @watched_talks_in_year = @user.watched_talks
      .includes(talk: [:event, :speakers, :approved_topics])
      .where(created_at: year_range)
      .order(created_at: :asc)

    @total_talks_watched = @watched_talks_in_year.count
    @total_watch_time_seconds = @watched_talks_in_year.sum(&:progress_seconds)
    @total_watch_time_hours = (@total_watch_time_seconds / 3600.0).round(1)

    @first_watched = @watched_talks_in_year.first
    @last_watched = @watched_talks_in_year.last

    talks_with_duration = @watched_talks_in_year.select { |wt| wt.talk.duration_in_seconds.to_i.positive? }
    @longest_watched = talks_with_duration.max_by { |wt| wt.talk.duration_in_seconds }
    @shortest_watched = talks_with_duration.min_by { |wt| wt.talk.duration_in_seconds }

    @top_topics = @watched_talks_in_year
      .flat_map { |wt| wt.talk.approved_topics }
      .compact
      .reject { |topic| topic.name.downcase.in?(["ruby", "ruby on rails"]) }
      .tally
      .sort_by { |_, count| -count }
      .first(5)

    @top_speakers = @watched_talks_in_year
      .flat_map { |wt| wt.talk.speakers }
      .compact
      .reject { |speaker| speaker.id == @user.id }
      .tally
      .sort_by { |_, count| -count }
      .first(5)

    @favorite_speaker = @top_speakers.first&.first

    @top_events = @watched_talks_in_year
      .map { |wt| wt.talk.event }
      .compact
      .tally
      .sort_by { |_, count| -count }
      .first(5)

    @countries_watched = @watched_talks_in_year
      .map { |wt| wt.talk.event&.country }
      .compact
      .uniq
      .sort_by { |c| c.translations["en"] }

    @languages_watched = @watched_talks_in_year
      .map { |wt| wt.talk.language }
      .compact
      .tally
      .sort_by { |_, count| -count }
      .first(5)
      .map { |code, count| [Language.by_code(code) || code, count] }

    @monthly_breakdown = @watched_talks_in_year
      .group_by { |wt| wt.created_at.month }
      .transform_values(&:count)

    @weekday_breakdown = @watched_talks_in_year
      .group_by { |wt| wt.created_at.wday }
      .transform_values(&:count)

    @most_active_month = @monthly_breakdown.max_by { |_, count| count }&.first
    @most_active_weekday = @weekday_breakdown.max_by { |_, count| count }&.first

    @talk_kinds = @watched_talks_in_year
      .map { |wt| wt.talk.kind }
      .compact
      .tally
      .sort_by { |_, count| -count }

    @bookmarks_in_year = @user.watch_lists
      .joins(:watch_list_talks)
      .where(watch_list_talks: {created_at: year_range})
      .distinct
      .count

    @events_attended_in_year = @user.participated_events
      .where(start_date: year_range)
      .includes(:series)
      .order(start_date: :asc)

    @events_as_speaker = @user.event_participations
      .where(attended_as: [:speaker, :keynote_speaker])
      .joins(:event)
      .where(events: {start_date: year_range})
      .count

    @events_as_visitor = @user.event_participations
      .where(attended_as: :visitor)
      .joins(:event)
      .where(events: {start_date: year_range})
      .count

    @countries_visited = @events_attended_in_year
      .map(&:country)
      .compact
      .uniq
      .sort_by { |c| c.translations["en"] }

    @talks_given_in_year = @user.kept_talks
      .includes(:event)
      .where(date: year_range)
      .order(date: :asc)

    @total_views_on_talks = @talks_given_in_year.sum(:view_count)
    @total_likes_on_talks = @talks_given_in_year.sum(:like_count)
    @total_speaking_minutes = (@talks_given_in_year.sum(:duration_in_seconds) / 60.0).round

    if @talks_given_in_year.any?
      talk_ids = @talks_given_in_year.pluck(:id)

      @talk_watchers_count = User
        .joins(:watched_talks)
        .where(watched_talks: {talk_id: talk_ids})
        .where.not(id: @user.id)
        .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
        .distinct
        .count

      @top_talk_watchers = User
        .joins(:watched_talks)
        .where(watched_talks: {talk_id: talk_ids})
        .where.not(id: @user.id)
        .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
        .group("users.id")
        .select("users.*, COUNT(DISTINCT watched_talks.talk_id) as watched_count")
        .order("watched_count DESC")
        .limit(3)
    else
      @talk_watchers_count = 0
      @top_talk_watchers = []
    end

    all_stamps = Stamp.for(events: @events_attended_in_year)
    event_stamps = @events_attended_in_year.flat_map { |event| Stamp.for_event(event) }
    all_stamps = (all_stamps + event_stamps).uniq(&:code)

    @country_stamps = all_stamps.select(&:has_country?)
    @event_stamps = all_stamps.select(&:has_event?)
    @achievement_stamps = []

    if @events_as_speaker.positive? && Stamp.conference_speaker_stamp
      @achievement_stamps << Stamp.conference_speaker_stamp
    end

    if @user.event_participations.joins(:event).where(attended_as: [:speaker, :keynote_speaker], events: {kind: :meetup, start_date: year_range}).exists? && Stamp.meetup_speaker_stamp
      @achievement_stamps << Stamp.meetup_speaker_stamp
    end

    if @events_attended_in_year.any? && Stamp.attend_one_event_stamp
      @achievement_stamps << Stamp.attend_one_event_stamp
    end

    @stamps_earned = (@country_stamps + @event_stamps + @achievement_stamps).uniq(&:code)
    @stickers_earned = @events_attended_in_year.flat_map { |event| Sticker.for_event(event) }.uniq(&:code)

    @event_map_markers = event_map_markers(@events_attended_in_year)

    @conference_buddies = find_conference_buddies
    @watch_twin = find_watch_twin
    @personality = determine_personality

    @speakers_discovered = @watched_talks_in_year
      .flat_map { |wt| wt.talk.speakers }
      .compact
      .uniq
      .count

    @events_discovered = @watched_talks_in_year
      .map { |wt| wt.talk.event }
      .compact
      .uniq
      .count

    completed_talks = @watched_talks_in_year.select { |wt| wt.progress_percentage >= 90 }
    @completion_rate = @total_talks_watched.positive? ? ((completed_talks.count.to_f / @total_talks_watched) * 100).round : 0
    @longest_streak = calculate_longest_streak

    @ruby_friends_met = User
      .joins(:event_participations)
      .where(event_participations: {event_id: @events_attended_in_year.pluck(:id)})
      .where.not(id: @user.id)
      .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
      .distinct
      .count

    @is_contributor = @user.contributor?
    @contributor = @user.contributor
    @has_passport = @user.passports.any?
    @passports = @user.passports

    @involvements_in_year = @user.event_involvements
      .joins(:event)
      .where(events: {start_date: year_range})
      .includes(:event)
    @involvements_by_role = @involvements_in_year.group_by(&:role)

    @share_url = profile_wrapped_index_url(profile_slug: @user.to_param)

    unless @user.wrapped_card.attached? && @user.wrapped_card_horizontal.attached?
      GenerateWrappedScreenshotJob.perform_later(@user)
    end

    @wrapped_locals = wrapped_locals

    render layout: "wrapped"
  end

  def card
    @year = YEAR
    year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @watched_talks_in_year = @user.watched_talks.where(created_at: year_range)
    @total_talks_watched = @watched_talks_in_year.count
    @total_watch_time_seconds = @watched_talks_in_year.sum(&:progress_seconds)
    @total_watch_time_hours = (@total_watch_time_seconds / 3600.0).round(1)

    @events_attended_in_year = @user.participated_events.where(start_date: year_range)
    @talks_given_in_year = @user.kept_talks.where(date: year_range)
    @countries_visited = @events_attended_in_year.map(&:country).compact.uniq

    @top_topics = @watched_talks_in_year
      .includes(talk: :approved_topics)
      .flat_map { |wt| wt.talk.approved_topics }
      .compact
      .tally
      .sort_by { |_, count| -count }
      .first(3)

    @personality = determine_personality
    @share_url = profile_wrapped_index_url(profile_slug: @user.to_param)

    render layout: "wrapped"
  end

  def toggle_visibility
    @user.update!(wrapped_public: !@user.wrapped_public?)

    @year = YEAR
    @is_owner = true
    year_range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)

    @watched_talks_in_year = @user.watched_talks.where(created_at: year_range)
    @total_talks_watched = @watched_talks_in_year.count
    @events_attended_in_year = @user.participated_events.where(start_date: year_range)
    @talks_given_in_year = @user.kept_talks.where(date: year_range)
    @share_url = profile_wrapped_index_url(profile_slug: @user.to_param)

    respond_to do |format|
      format.html { redirect_to profile_wrapped_index_path(profile_slug: @user.slug) }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("wrapped-share", partial: "profiles/wrapped/share") }
    end
  end

  def og_image
    unless @user.wrapped_card_horizontal.attached?
      generator = User::WrappedScreenshotGenerator.new(@user, orientation: :horizontal)
      generator.save_to_storage
    end

    if @user.wrapped_card_horizontal.attached?
      redirect_to rails_blob_url(@user.wrapped_card_horizontal), allow_other_host: true
    else
      head :internal_server_error
    end
  end

  def generate_card
    orientation = params[:orientation]&.to_sym || :vertical
    attachment = (orientation == :horizontal) ? @user.wrapped_card_horizontal : @user.wrapped_card

    unless attachment.attached?
      generator = User::WrappedScreenshotGenerator.new(@user, orientation: orientation)
      generator.save_to_storage
      attachment.reload
    end

    if attachment.attached?
      redirect_to rails_blob_path(attachment, disposition: "attachment")
    else
      redirect_to profile_wrapped_index_path(profile_slug: @user.to_param), alert: "Failed to generate card. Please try again."
    end
  end

  private

  def calculate_longest_streak
    return 0 if @watched_talks_in_year.empty?

    watch_dates = @watched_talks_in_year.map { |wt| wt.created_at.to_date }.uniq.sort
    return 1 if watch_dates.size == 1

    max_streak = 1
    current_streak = 1

    watch_dates.each_cons(2) do |prev_date, curr_date|
      if curr_date - prev_date == 1
        current_streak += 1
        max_streak = [max_streak, current_streak].max
      else
        current_streak = 1
      end
    end

    max_streak
  end

  def determine_personality
    return "Ruby Explorer" if @top_topics.empty?

    all_topic_names = @top_topics.map { |topic, _| topic.name.downcase }

    personality_matches = {
      "Hotwire Hero" => %w[hotwire turbo stimulus turbo-native],
      "Frontend Artisan" => %w[javascript css frontend ui vue react angular viewcomponent],
      "Testing Guru" => %w[testing test-driven rspec minitest capybara vcr],
      "Performance Optimizer" => %w[performance optimization caching benchmarking memory profiling],
      "Security Champion" => %w[security authentication authorization encryption vulnerability],
      "Data Architect" => %w[postgresql database sql activerecord mysql sqlite redis elasticsearch],
      "API Artisan" => %w[api graphql rest grpc json],
      "DevOps Pioneer" => %w[devops deployment docker kubernetes aws heroku kamal ci/cd],
      "Architecture Astronaut" => %w[architecture microservices monolith modular design-patterns solid],
      "Ruby Internist" => %w[ruby-vm ruby-internals yjit garbage-collection jruby truffleruby mruby parser ast],
      "Concurrency Connoisseur" => %w[concurrency async threading ractor fiber sidekiq background],
      "AI Adventurer" => %w[machine-learning artificial-intelligence ai llm openai langchain],
      "Community Champion" => %w[open-source community mentorship diversity inclusion],
      "Growth Mindset" => %w[career-development personal-development leadership team-building mentorship],
      "Code Craftsperson" => %w[refactoring code-quality clean-code debugging error-handling]
    }

    personality_matches.each do |personality, keywords|
      if all_topic_names.any? { |topic| keywords.any? { |keyword| topic.include?(keyword) } }
        return personality
      end
    end

    top_topic = @top_topics.first&.first&.name&.downcase

    case top_topic
    when /rails/
      "Rails Enthusiast"
    when /developer.?experience|dx/
      "DX Advocate"
    when /web/
      "Web Developer"
    when /software/
      "Software Craftsperson"
    when /gem/
      "Gem Hunter"
    when /debug/
      "Bug Squasher"
    when /learn|education|teach/
      "Eternal Learner"
    when /startup|entrepreneur|business/
      "Ruby Entrepreneur"
    when /legacy|maintain/
      "Legacy Whisperer"
    when /mobile|ios|android/
      "Mobile Maverick"
    when /real.?time|websocket|action.?cable/
      "Real-Time Ranger"
    when /background|job|queue|sidekiq/
      "Background Boss"
    when /monolith|majestic/
      "Monolith Master"
    else
      "Rubyist"
    end
  end

  def find_conference_buddies
    return [] if @events_attended_in_year.empty?

    event_ids = @events_attended_in_year.pluck(:id)

    User
      .joins(:event_participations)
      .where(event_participations: {event_id: event_ids})
      .where.not(id: @user.id)
      .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
      .group("users.id")
      .select("users.*, COUNT(event_participations.id) as shared_events_count")
      .order("shared_events_count DESC")
      .limit(10)
      .map do |buddy|
        shared_events = @events_attended_in_year.where(
          id: buddy.event_participations.where(event_id: event_ids).pluck(:event_id)
        )
        OpenStruct.new(
          user: buddy,
          shared_count: buddy.shared_events_count,
          shared_events: shared_events
        )
      end
  end

  def find_watch_twin
    return nil if @watched_talks_in_year.empty?

    talk_ids = @watched_talks_in_year.map { |wt| wt.talk_id }

    twin = User
      .joins(:watched_talks)
      .where(watched_talks: {talk_id: talk_ids})
      .where.not(id: @user.id)
      .where.not("LOWER(users.name) IN (?)", ["tbd", "todo", "tba", "speaker tbd", "speaker tba"])
      .group("users.id")
      .select("users.*, COUNT(DISTINCT watched_talks.talk_id) as shared_talks_count")
      .order("shared_talks_count DESC")
      .first

    return nil unless twin && twin.shared_talks_count >= 3

    OpenStruct.new(
      user: twin,
      shared_count: twin.shared_talks_count,
      percentage: ((twin.shared_talks_count.to_f / talk_ids.size) * 100).round
    )
  end

  def check_wrapped_access
    is_owner = @user == Current.user
    is_admin = Current.user&.admin?

    unless is_owner || is_admin || @user.wrapped_public?
      render "private", layout: "wrapped"
    end
  end

  def require_owner
    unless @user == Current.user || Current.user&.admin?
      redirect_to profile_path(@user), alert: "You can only change your own wrapped visibility"
    end
  end

  def wrapped_locals
    {
      user: @user,
      year: @year,
      is_owner: @is_owner,
      total_talks_watched: @total_talks_watched,
      total_watch_time_hours: @total_watch_time_hours,
      total_watch_time_seconds: @total_watch_time_seconds,
      events_attended_in_year: @events_attended_in_year,
      talks_given_in_year: @talks_given_in_year,
      countries_visited: @countries_visited,
      top_topics: @top_topics,
      top_speakers: @top_speakers,
      favorite_speaker: @favorite_speaker,
      top_events: @top_events,
      countries_watched: @countries_watched,
      languages_watched: @languages_watched,
      monthly_breakdown: @monthly_breakdown,
      weekday_breakdown: @weekday_breakdown,
      most_active_month: @most_active_month,
      most_active_weekday: @most_active_weekday,
      talk_kinds: @talk_kinds,
      bookmarks_in_year: @bookmarks_in_year,
      events_as_speaker: @events_as_speaker,
      events_as_visitor: @events_as_visitor,
      total_views_on_talks: @total_views_on_talks,
      total_likes_on_talks: @total_likes_on_talks,
      total_speaking_minutes: @total_speaking_minutes,
      talk_watchers_count: @talk_watchers_count,
      top_talk_watchers: @top_talk_watchers,
      country_stamps: @country_stamps,
      event_stamps: @event_stamps,
      achievement_stamps: @achievement_stamps,
      stamps_earned: @stamps_earned,
      stickers_earned: @stickers_earned,
      event_map_markers: @event_map_markers,
      conference_buddies: @conference_buddies,
      watch_twin: @watch_twin,
      personality: @personality,
      speakers_discovered: @speakers_discovered,
      events_discovered: @events_discovered,
      completion_rate: @completion_rate,
      longest_streak: @longest_streak,
      ruby_friends_met: @ruby_friends_met,
      is_contributor: @is_contributor,
      contributor: @contributor,
      has_passport: @has_passport,
      passports: @passports,
      involvements_in_year: @involvements_in_year,
      involvements_by_role: @involvements_by_role,
      share_url: @share_url,
      first_watched: @first_watched,
      last_watched: @last_watched,
      longest_watched: @longest_watched,
      shortest_watched: @shortest_watched
    }
  end
end
