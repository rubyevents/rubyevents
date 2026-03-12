class ProfilesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_user, only: %i[show edit update reindex]
  before_action :set_favorite_user, only: %i[show]
  before_action :set_user_favorites, only: %i[show]
  before_action :set_mutual_events, only: %i[show]
  before_action :require_admin!, only: %i[reindex]

  include Pagy::Backend
  include RemoteModal
  include WatchedTalks

  respond_with_remote_modal only: [:edit]

  # GET /profiles/:slug
  def show
    load_profile_data_for_show

    if @user.suspicious?
      set_meta_tags(robots: "noindex, nofollow")
    else
      set_meta_tags(@user)
    end
  end

  # GET /profiles/:slug/edit
  def edit
    set_modal_options(size: :lg)
  end

  # PATCH/PUT /profiles/:slug
  def update
    suggestion = @user.create_suggestion_from(params: user_params, user: Current.user)
    if suggestion.persisted?
      redirect_to profile_path(@user), notice: suggestion.notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /profiles/:slug/reindex
  def reindex
    Search::Backend.index(@user)
    @user.talks.find_each { |talk| Search::Backend.index(talk) }

    redirect_to profile_path(@user), notice: "Profile reindexed successfully."
  end

  private

  def require_admin!
    redirect_to profile_path(@user), alert: "Not authorized" unless Current.user&.admin?
  end

  def load_profile_data_for_show
    @talks = @user.kept_talks.includes(:speakers, event: :series, child_talks: :speakers).order(date: :desc)
    @talks_by_kind = @talks.group_by(&:kind)
    @topics = @user.topics.approved.tally.sort_by(&:last).reverse.map(&:first)
    # Load participated events (from event_participations)
    @events = @user.participated_events.includes(:series).distinct.in_order_of(:attended_as, EventParticipation.attended_as.keys)
    @events_with_stickers = @events.select(&:sticker?)

    event_participations = @user.event_participations.includes(:event).where(event: @events)
    @participations = event_participations.index_by(&:event_id)

    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }

    # Group events by country for the map tab
    @countries_with_events = @events.grouped_by_country

    @involved_events = @user.involved_events.includes(:series).distinct.order(start_date: :desc)
    event_involvements = @user.event_involvements.includes(:event).where(event: @involved_events)
    involvement_lookup = event_involvements.group_by(&:event_id)

    @involvements_by_role = {}
    @involved_events.each do |event|
      involvements = involvement_lookup[event.id] || []
      involvements.each do |involvement|
        @involvements_by_role[involvement.role] ||= []
        @involvements_by_role[involvement.role] << event
      end
    end

    @stamps = Stamp.for_user(@user)
    @aliases = Current.user&.admin? ? @user.aliases : []

    @back_path = speakers_path
  end

  helper_method :user_kind
  def user_kind
    return params[:user_kind] if params[:user_kind].present? && Rails.env.development?
    return :admin if Current.user&.admin?
    return :owner if @user.managed_by?(Current.user)
    return :signed_in if Current.user.present?

    :anonymous
  end

  def set_user
    @user = User.preloaded.includes(:talks).find_by_slug_or_alias(params[:slug])
    @user = User.preloaded.includes(:talks).find_by_github_handle(params[:slug]) unless @user.present?

    if @user.blank?
      redirect_to speakers_path, status: :moved_permanently, notice: "User not found"
      return
    end

    if @user.canonical.present?
      redirect_to profile_path(@user.canonical), status: :moved_permanently
      return
    end

    if params[:slug] != @user.to_param
      redirect_to profile_path(@user), status: :moved_permanently
    end
  end

  def user_params
    params.require(:user).permit(
      :name,
      :github_handle,
      :twitter,
      :bsky,
      :linkedin,
      :mastodon,
      :bio,
      :website,
      :location,
      :speakerdeck,
      :pronouns_type,
      :pronouns,
      :slug
    )
  end

  def set_favorite_user
    @favorite_user = Current.user ? @user.favorited_by.find_or_initialize_by(user: Current.user) : nil
  end

  def set_mutual_events
    @mutual_events = if Current.user
      @user.participated_events.where(id: Current.user.participated_events).distinct.order(start_date: :desc)
    else
      Event.none
    end
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
