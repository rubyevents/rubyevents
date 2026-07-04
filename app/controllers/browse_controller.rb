class BrowseController < ApplicationController
  skip_before_action :authenticate_user!

  CACHE_VERSION = "v1"
  CACHE_EXPIRY = 15.minutes

  SECTIONS = %w[
    featured_events continue_watching event_rows newest_talks recently_published
    trending for_you from_bookmarks favorite_rubyists events_attended
    unwatched_attended favorite_speakers popular popular_youtube most_bookmarked
    quick_watches deep_dives hidden_gems evergreen beginner_friendly mind_blowing
    inspiring most_liked recommended_community popular_topics talk_kinds topic_rows
    language_rows closing_cfps upcoming_events recent_events featured_organizations
    upcoming_events_europe upcoming_events_north_america upcoming_events_south_america
    upcoming_events_asia upcoming_events_australia upcoming_events_africa
    talk_languages always_open_cfps
  ].freeze

  def index
    load_featured_events
    load_continue_watching
    load_event_rows
  end

  def show
    section_name = params[:id]
    return head :not_found unless SECTIONS.include?(section_name)

    send("load_#{section_name}")
    render partial: "browse/sections/#{section_name}", locals: instance_variables_for_section(section_name)
  end

  private

  def instance_variables_for_section(section_name)
    case section_name
    when "featured_events" then {events: @featured_events}
    when "continue_watching" then {continue_watching: @continue_watching}
    when "event_rows" then {event_rows: @event_rows}
    when "newest_talks" then {talks: @newest_talks}
    when "recently_published" then {talks: @recently_published}
    when "trending" then {talks: @trending_talks}
    when "for_you" then {talks: @recommended_talks}
    when "from_bookmarks" then {talks: @from_your_bookmarks}
    when "favorite_rubyists" then {talks: @favorite_rubyists_talks}
    when "events_attended" then {talks: @from_events_attended}
    when "unwatched_attended" then {talks: @unwatched_from_attended}
    when "favorite_speakers" then {talks: @from_favorite_speakers}
    when "popular" then {talks: @popular_talks}
    when "popular_youtube" then {talks: @popular_on_youtube}
    when "most_bookmarked" then {talks: @most_bookmarked}
    when "quick_watches" then {talks: @quick_watches}
    when "deep_dives" then {talks: @deep_dives}
    when "hidden_gems" then {talks: @hidden_gems}
    when "evergreen" then {talks: @evergreen_talks}
    when "beginner_friendly" then {talks: @beginner_friendly}
    when "mind_blowing" then {talks: @mind_blowing}
    when "inspiring" then {talks: @inspiring_talks}
    when "most_liked" then {talks: @most_liked}
    when "recommended_community" then {talks: @recommended_by_community}
    when "popular_topics" then {topics: @popular_topics}
    when "talk_kinds" then {talk_kinds: @talk_kinds}
    when "talk_languages" then {languages: @talk_languages}
    when "topic_rows" then {topic_rows: @topic_rows}
    when "language_rows" then {language_rows: @language_rows}
    when "closing_cfps" then {events: @closing_cfp_events}
    when "always_open_cfps" then {events: @always_open_cfp_events}
    when "upcoming_events" then {events: @upcoming_events}
    when "recent_events" then {events: @recent_events}
    when "featured_organizations" then {organizations: @featured_organizations}
    when /\Aupcoming_events_(\w+)\z/ then {events: @continent_events, continent: @continent}
    else {}
    end
  end

  def cache_key(name)
    "browse/#{name}/#{CACHE_VERSION}"
  end

  def load_featured_events
    ids = Rails.cache.fetch(cache_key("featured_events"), expires_in: CACHE_EXPIRY) do
      featured_events_query.pluck(:id)
    end

    @featured_events = Event.includes(:series, :keynote_speakers, :speakers).where(id: ids).in_order_of(:id, ids)
  end

  def load_event_rows
    sections = Rails.cache.fetch(cache_key("event_rows"), expires_in: CACHE_EXPIRY) do
      build_event_sections
    end

    event_ids = sections.map { |section| section[:event_id] }.compact.uniq
    events_by_id = Event.includes(:series).where(id: event_ids).index_by(&:id)

    @event_rows = sections.map do |section|
      {
        event: events_by_id[section[:event_id]],
        talks: Talk.includes(:speakers, event: :series)
          .where(id: section[:talk_ids])
          .in_order_of(:id, section[:talk_ids])
      }
    end.select { |row| row[:event].present? }
  end

  def load_continue_watching
    return unless Current.user

    @continue_watching = Current.user.watched_talks
      .in_progress
      .includes(talk: [:speakers, event: :series])
      .order(updated_at: :desc)
      .limit(12)
  end

  def load_newest_talks
    ids = Rails.cache.fetch(cache_key("newest_talks"), expires_in: CACHE_EXPIRY) do
      newest_talks_query.pluck(:id)
    end

    @newest_talks = Talk.includes(:speakers, event: :series)
      .where(id: ids)
      .in_order_of(:id, ids)
  end

  def load_recently_published
    ids = Rails.cache.fetch(cache_key("recently_published"), expires_in: CACHE_EXPIRY) do
      recently_published_query.pluck(:id)
    end

    @recently_published = Talk.includes(:speakers, event: :series)
      .where(id: ids)
      .in_order_of(:id, ids)
  end

  def load_trending
    ids = Rails.cache.fetch(cache_key("trending"), expires_in: CACHE_EXPIRY) do
      trending_talks_query.pluck(:id)
    end

    @trending_talks = Talk.includes(:speakers, event: :series)
      .where(id: ids)
      .in_order_of(:id, ids)
  end

  def load_for_you
    return unless Current.user

    @recommended_talks = Current.user.talk_recommender.talks(limit: 12)
  end

  def load_from_bookmarks
    return unless Current.user

    @from_your_bookmarks = Current.user.default_watch_list.talks
      .watchable
      .includes(:speakers, event: :series)
      .order(Arel.sql("RANDOM()"))
      .limit(15)
  end

  def load_favorite_rubyists
    return unless Current.user

    favorite_user_ids = FavoriteUser.where(user: Current.user).pluck(:favorite_user_id)
    return unless favorite_user_ids.any?

    @favorite_rubyists_talks = Talk.watchable
      .joins(:user_talks)
      .where(user_talks: {user_id: favorite_user_ids})
      .includes(:speakers, event: :series)
      .order(date: :desc)
      .limit(15)
  end

  def load_events_attended
    return unless Current.user

    attended_event_ids = Current.user.participated_events.pluck(:id)
    return unless attended_event_ids.any?

    watched_talk_ids = Current.user.watched_talks.pluck(:talk_id)
    own_talk_ids = Current.user.user_talks.select(:talk_id)

    @from_events_attended = Talk.watchable
      .where(event_id: attended_event_ids)
      .where.not(id: watched_talk_ids)
      .where.not(id: own_talk_ids)
      .includes(:speakers, event: :series)
      .order(date: :desc)
      .limit(15)
  end

  def load_unwatched_attended
    return unless Current.user

    attended_event_ids = Current.user.participated_events.pluck(:id)
    return unless attended_event_ids.any?

    watched_talk_ids = Current.user.watched_talks.pluck(:talk_id)

    @unwatched_from_attended = Talk.watchable
      .where(event_id: attended_event_ids)
      .where.not(id: watched_talk_ids)
      .includes(:speakers, event: :series)
      .order(Arel.sql("RANDOM()"))
      .limit(15)
  end

  def load_favorite_speakers
    return unless Current.user

    watched_talk_ids = Current.user.watched_talks.pluck(:talk_id)
    return unless watched_talk_ids.any?

    top_speaker_ids = UserTalk
      .where(talk_id: watched_talk_ids)
      .group(:user_id)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(10)
      .pluck(:user_id)
    return unless top_speaker_ids.any?

    own_talk_ids = Current.user.user_talks.select(:talk_id)

    @from_favorite_speakers = Talk.watchable
      .joins(:user_talks)
      .where(user_talks: {user_id: top_speaker_ids})
      .where.not(id: watched_talk_ids)
      .where.not(id: own_talk_ids)
      .includes(:speakers, event: :series)
      .order(Arel.sql("RANDOM()"))
      .limit(15)
  end

  def load_popular
    ids = Rails.cache.fetch(cache_key("popular"), expires_in: CACHE_EXPIRY) do
      popular_talks_query.pluck(:id)
    end

    @popular_talks = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_popular_youtube
    ids = Rails.cache.fetch(cache_key("popular_youtube"), expires_in: CACHE_EXPIRY) do
      popular_on_youtube_query.pluck(:id)
    end

    @popular_on_youtube = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_most_bookmarked
    ids = Rails.cache.fetch(cache_key("most_bookmarked"), expires_in: CACHE_EXPIRY) do
      most_bookmarked_query.pluck(:id)
    end

    @most_bookmarked = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_quick_watches
    ids = Rails.cache.fetch(cache_key("quick_watches"), expires_in: CACHE_EXPIRY) do
      quick_watches_query.pluck(:id)
    end

    @quick_watches = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_deep_dives
    ids = Rails.cache.fetch(cache_key("deep_dives"), expires_in: CACHE_EXPIRY) do
      deep_dives_query.pluck(:id)
    end

    @deep_dives = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_hidden_gems
    ids = Rails.cache.fetch(cache_key("hidden_gems"), expires_in: CACHE_EXPIRY) do
      hidden_gems_query.pluck(:id)
    end

    @hidden_gems = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_evergreen
    ids = Rails.cache.fetch(cache_key("evergreen"), expires_in: CACHE_EXPIRY) do
      evergreen_talks_query.pluck(:id)
    end

    @evergreen_talks = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_beginner_friendly
    ids = Rails.cache.fetch(cache_key("beginner_friendly"), expires_in: CACHE_EXPIRY) do
      beginner_friendly_query.pluck(:id)
    end

    @beginner_friendly = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_mind_blowing
    ids = Rails.cache.fetch(cache_key("mind_blowing"), expires_in: CACHE_EXPIRY) do
      mind_blowing_query.pluck(:id)
    end

    @mind_blowing = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_inspiring
    ids = Rails.cache.fetch(cache_key("inspiring"), expires_in: CACHE_EXPIRY) do
      inspiring_talks_query.pluck(:id)
    end

    @inspiring_talks = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_most_liked
    ids = Rails.cache.fetch(cache_key("most_liked"), expires_in: CACHE_EXPIRY) do
      most_liked_query.pluck(:id)
    end

    @most_liked = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_recommended_community
    ids = Rails.cache.fetch(cache_key("recommended_community"), expires_in: CACHE_EXPIRY) do
      recommended_by_community_query.pluck(:id)
    end

    @recommended_by_community = Talk.includes(:speakers, event: :series).where(id: ids).in_order_of(:id, ids)
  end

  def load_popular_topics
    ids = Rails.cache.fetch(cache_key("popular_topics"), expires_in: CACHE_EXPIRY) do
      popular_topics_query.pluck(:id)
    end

    @popular_topics = Topic.includes(:topic_gems).where(id: ids).in_order_of(:id, ids)
  end

  def load_talk_kinds
    @talk_kinds = Rails.cache.fetch(cache_key("talk_kinds"), expires_in: CACHE_EXPIRY) do
      talk_kinds_query
    end
  end

  def load_topic_rows
    sections = Rails.cache.fetch(cache_key("topic_rows"), expires_in: CACHE_EXPIRY) do
      build_topic_sections
    end

    topic_ids = sections.map { |section| section[:topic_id] }.compact.uniq
    topics_by_id = Topic.where(id: topic_ids).index_by(&:id)

    @topic_rows = sections.map do |section|
      {
        topic: topics_by_id[section[:topic_id]],
        talks: Talk.includes(:speakers, event: :series)
          .where(id: section[:talk_ids])
          .in_order_of(:id, section[:talk_ids])
      }
    end.select { |row| row[:topic].present? }
  end

  def load_language_rows
    return @language_rows = [] unless Current.user

    understood_languages = Current.user.languages.understood - ["en"]
    return @language_rows = [] unless understood_languages.any?

    watched_talk_ids = Current.user.watched_talks.pluck(:talk_id)

    @language_rows = understood_languages.map do |lang_code|
      language_name = Language.by_code(lang_code)
      talks = Talk.watchable
        .where(language: lang_code)
        .where.not(id: watched_talk_ids)
        .includes(:speakers, event: :series)
        .order(date: :desc)
        .limit(15)

      next if talks.empty?

      {
        language_code: lang_code,
        language_name: language_name || lang_code.upcase,
        talks: talks
      }
    end.compact
  end

  def featured_events_query
    Event
      .not_meetup
      .where.not(recordings_published_date: nil)
      .featurable
      .where.not(home_sort_date: nil)
      .order(home_sort_date: :desc)
      .limit(5)
  end

  def recently_published_query = Talk.recently_published_talks.limit(15)
  def newest_talks_query = Talk.newest_talks.limit(15)
  def trending_talks_query = Talk.trending_talks.limit(15)
  def popular_talks_query = Talk.popular_talks.limit(15)
  def popular_on_youtube_query = Talk.popular_on_youtube_talks.limit(15)
  def most_bookmarked_query = Talk.most_bookmarked_talks.limit(15)
  def quick_watches_query = Talk.quick_watches_talks.order(Arel.sql("RANDOM()")).limit(15)
  def deep_dives_query = Talk.deep_dives_talks.order(Arel.sql("RANDOM()")).limit(15)
  def hidden_gems_query = Talk.hidden_gems_talks.limit(15)
  def evergreen_talks_query = Talk.evergreen_talks.limit(15)
  def beginner_friendly_query = Talk.beginner_friendly_talks.limit(15)

  def mind_blowing_query = Talk.mind_blowing_talks.limit(15)
  def inspiring_talks_query = Talk.inspiring_talks.limit(15)
  def most_liked_query = Talk.most_liked_talks.limit(15)
  def recommended_by_community_query = Talk.recommended_by_community_talks.limit(15)

  def popular_topics_query
    Topic.approved
      .joins(:talks)
      .where(talks: {video_provider: Talk::WATCHABLE_PROVIDERS})
      .group("topics.id")
      .order(Arel.sql("COUNT(talks.id) DESC"))
      .limit(12)
  end

  def load_talk_languages
    @talk_languages = Rails.cache.fetch(cache_key("talk_languages"), expires_in: CACHE_EXPIRY) do
      Talk.watchable
        .where.not(language: nil)
        .group(:language)
        .order(Arel.sql("COUNT(*) DESC"))
        .count
    end
  end

  def talk_kinds_query
    Talk.watchable
      .group(:kind)
      .order(Arel.sql("COUNT(*) DESC"))
      .count
  end

  def build_topic_sections
    Topic.approved
      .joins(:talks)
      .where(talks: {video_provider: Talk::WATCHABLE_PROVIDERS})
      .group("topics.id")
      .having("COUNT(talks.id) >= 5")
      .order(Arel.sql("COUNT(talks.id) DESC"))
      .limit(4)
      .map do |topic|
        {
          topic_id: topic.id,
          talk_ids: topic.talks.watchable.order(date: :desc).limit(15).pluck(:id)
        }
      end
  end

  def build_event_sections
    Event.joins(:talks)
      .where(talks: {video_provider: Talk::WATCHABLE_PROVIDERS})
      .where("talks.published_at > ?", 12.months.ago)
      .group("events.id")
      .having("COUNT(talks.id) >= 3")
      .order(Arel.sql("MAX(talks.published_at) DESC"))
      .limit(6)
      .map do |event|
        {
          event_id: event.id,
          talk_ids: event.talks.watchable.order(date: :desc).limit(15).pluck(:id)
        }
      end
  end

  def load_closing_cfps
    @closing_cfp_events = Event
      .joins(:cfps)
      .merge(CFP.open.where.not(close_date: nil))
      .includes(:series, :cfps)
      .order("cfps.close_date ASC")
      .distinct
      .limit(10)
  end

  def load_always_open_cfps
    @always_open_cfp_events = Event
      .joins(:cfps)
      .merge(CFP.open.where(close_date: nil))
      .includes(:series, :cfps)
      .distinct
      .limit(15)
  end

  def load_upcoming_events
    @upcoming_events = Event.upcoming
      .includes(:series)
      .limit(15)
  end

  def load_recent_events
    @recent_events = Event.conference.past
      .includes(:series)
      .limit(15)
  end

  %w[europe north_america south_america asia australia africa].each do |continent_key|
    define_method("load_upcoming_events_#{continent_key}") do
      slug = continent_key.tr("_", "-")
      @continent = Continent.find(slug)
      @continent_events = Event.upcoming
        .includes(:series)
        .where(country_code: @continent.country_codes)
        .limit(15)
    end
  end

  def load_featured_organizations
    ids = Rails.cache.fetch(cache_key("featured_organizations"), expires_in: CACHE_EXPIRY) do
      Organization.joins(:sponsors)
        .group("organizations.id")
        .order("COUNT(sponsors.id) DESC")
        .limit(10)
        .pluck(:id)
    end

    @featured_organizations = Organization.includes(:events).where(id: ids).in_order_of(:id, ids)
  end
end
