class TalksController < ApplicationController
  include FavoriteUsers
  include Pagy::Backend
  include WatchedTalks

  skip_before_action :authenticate_user!

  before_action :set_talk, only: %i[show]
  before_action :set_favorite_users, only: %i[show]
  before_action :set_user_favorites, only: %i[index show]

  SECTION_SCOPES = {
    "newest" => :newest_talks,
    "recently_published" => :recently_published_talks,
    "trending" => :trending_talks,
    "popular" => :popular_talks,
    "popular_youtube" => :popular_on_youtube_talks,
    "most_bookmarked" => :most_bookmarked_talks,
    "hidden_gems" => :hidden_gems_talks,
    "quick_watches" => :quick_watches_talks,
    "deep_dives" => :deep_dives_talks,
    "evergreen" => :evergreen_talks,
    "beginner_friendly" => :beginner_friendly_talks,
    "most_liked" => :most_liked_talks,
    "mind_blowing" => :mind_blowing_talks,
    "inspiring" => :inspiring_talks,
    "recommended_community" => :recommended_by_community_talks
  }.freeze

  SECTION_TITLES = {
    "newest" => "Recently Held",
    "recently_published" => "Recently Uploaded",
    "trending" => "Trending",
    "popular" => "Popular",
    "popular_youtube" => "Popular on YouTube",
    "most_bookmarked" => "Most Bookmarked",
    "hidden_gems" => "Hidden Gems",
    "quick_watches" => "Quick Watches",
    "deep_dives" => "Deep Dives",
    "evergreen" => "Evergreen",
    "beginner_friendly" => "Beginner Friendly",
    "most_liked" => "Most Liked",
    "mind_blowing" => "Mind-Blowing",
    "inspiring" => "Inspiring",
    "recommended_community" => "Recommended by the Community",
    "for_you" => "For You",
    "favorite_rubyists" => "From Your Favorite Rubyists",
    "favorite_speakers" => "More From Speakers You Watch",
    "events_attended" => "From Events You Attended"
  }.freeze

  PERSONALIZED_SECTIONS = %w[favorite_rubyists favorite_speakers events_attended].freeze

  # GET /talks
  def index
    load_sidebar_data

    if params[:section] == "for_you"
      @section_title = SECTION_TITLES["for_you"]
      if Current.user
        talks = Current.user.talk_recommender.talks(limit: 100)
        @pagy, @talks = pagy_array(talks, limit: 42)
      else
        @talks = []
        @sign_in_required = true
      end
    elsif PERSONALIZED_SECTIONS.include?(params[:section])
      @section_title = SECTION_TITLES[params[:section]]
      if Current.user
        @pagy, @talks = pagy(personalized_section_scope(params[:section]), limit: 42)
      else
        @talks = []
        @sign_in_required = true
      end
    elsif params[:section].present? && SECTION_SCOPES[params[:section]]
      scope = Talk.send(SECTION_SCOPES[params[:section]]).includes(:speakers, event: :series)
      @pagy, @talks = pagy(scope, limit: 42)
      @section_title = SECTION_TITLES[params[:section]]
    else
      @pagy, @talks = search_backend.search_talks_with_pagy(
        params[:s],
        pagy_backend: self,
        **search_options
      )

      load_status_counts
    end
  end

  # GET /talks/1
  def show
    set_meta_tags(@talk)
  end

  private

  def personalized_section_scope(section)
    case section
    when "favorite_rubyists"
      favorite_user_ids = FavoriteUser.where(user: Current.user).pluck(:favorite_user_id)
      return Talk.none if favorite_user_ids.empty?

      Talk.watchable
        .joins(:user_talks)
        .where(user_talks: {user_id: favorite_user_ids})
        .includes(:speakers, event: :series)
        .order(date: :desc)
        .distinct
    when "favorite_speakers"
      watched_talk_ids = Current.user.watched_talks.pluck(:talk_id)
      return Talk.none if watched_talk_ids.empty?

      top_speaker_ids = UserTalk
        .where(talk_id: watched_talk_ids)
        .group(:user_id)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(10)
        .pluck(:user_id)
      return Talk.none if top_speaker_ids.empty?

      Talk.watchable
        .joins(:user_talks)
        .where(user_talks: {user_id: top_speaker_ids})
        .where.not(id: watched_talk_ids)
        .where.not(id: Current.user.user_talks.select(:talk_id))
        .includes(:speakers, event: :series)
        .order(date: :desc)
        .distinct
    when "events_attended"
      attended_event_ids = Current.user.participated_events.pluck(:id)
      return Talk.none if attended_event_ids.empty?

      watched_talk_ids = Current.user.watched_talks.pluck(:talk_id)

      Talk.watchable
        .where(event_id: attended_event_ids)
        .where.not(id: watched_talk_ids)
        .where.not(id: Current.user.user_talks.select(:talk_id))
        .includes(:speakers, event: :series)
        .order(date: :desc)
    else
      Talk.none
    end
  end

  def search_backend
    @search_backend ||= Search::Backend.resolve(params[:search_backend])
  end

  def search_options
    {
      per_page: params[:limit]&.to_i || 42,
      page: params[:page]&.to_i || 1,
      sort: sort_key,
      topic_slug: params[:topic],
      event_slug: params[:event],
      speaker_slug: params[:speaker],
      kind: talk_kind,
      language: params[:language],
      created_after: created_after,
      status: params[:status].presence_in(%w[scheduled no_video all]),
      include_unwatchable: params[:status].in?(%w[all no_video])
    }.compact
  end

  def sort_key
    if params[:s].present? && !explicit_ordering_requested?
      "relevance"
    else
      params[:order_by].presence || "date_desc"
    end
  end

  helper_method :order_by_key
  def order_by_key
    if params[:s].present? && !explicit_ordering_requested?
      return "ranked"
    end

    params[:order_by].presence || "date_desc"
  end

  helper_method :filtered_search?
  def filtered_search?
    params[:s].present?
  end

  def explicit_ordering_requested?
    params[:order_by].present? && params[:order_by] != "ranked"
  end

  def created_after
    Date.parse(params[:created_after]) if params[:created_after].present?
  rescue ArgumentError
    nil
  end

  def talk_kind
    @talk_kind ||= params[:kind].presence_in(Talk.kinds.keys)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_talk
    @talk = Talk.includes(:approved_topics, :speakers, event: :series, watched_talks: :user).find_by(slug: params[:slug])
    @talk ||= Talk.find_by_slug_or_alias(params[:slug])

    return redirect_to talks_path, status: :moved_permanently if @talk.blank?

    return redirect_to talk_path(@talk), status: :moved_permanently if @talk.slug != params[:slug]
    @speakers = @talk.speakers.preloaded
  end

  helper_method :search_params
  def search_params
    params.permit(:s, :topic, :event, :speaker, :kind, :created_after, :all, :order_by, :status, :language, :section)
  end

  def load_status_counts
    base = Talk.all
    base = base.where(kind: params[:kind]) if params[:kind].present?
    base = base.where(language: params[:language]) if params[:language].present?
    base = base.for_topic(params[:topic]) if params[:topic].present?
    base = base.for_event(params[:event]) if params[:event].present?
    base = base.for_speaker(params[:speaker]) if params[:speaker].present?

    @status_counts = {
      all: base.count,
      watchable: base.watchable.count,
      no_video: base.where.not(video_provider: Talk::WATCHABLE_PROVIDERS).count
    }
  end

  def load_sidebar_data
    @sidebar_data = Rails.cache.fetch("talks_sidebar_data", expires_in: 1.hour) do
      {
        kind_counts: Talk.group(:kind).order(Arel.sql("COUNT(*) DESC")).count,
        language_counts: Language.used_counts,
        top_topics: Topic.approved
          .where.not(name: ["Ruby", "Ruby on Rails"])
          .joins(:talks)
          .group("topics.id")
          .order(Arel.sql("COUNT(talks.id) DESC"))
          .limit(15)
          .pluck(:id, :name, :slug, Arel.sql("COUNT(talks.id) as talks_count"))
      }
    end
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
