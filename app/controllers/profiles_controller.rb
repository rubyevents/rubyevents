class ProfilesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_user, only: %i[show edit update]
  before_action :set_user_favorites, only: %i[show]
  include Pagy::Backend
  include RemoteModal
  include WatchedTalks
  respond_with_remote_modal only: [:edit]

  # GET /profiles/:slug
  def show
    @talks = @user.kept_talks.includes(:speakers, event: :organisation, child_talks: :speakers).order(date: :desc)
    @talks_by_kind = @talks.group_by(&:kind)
    @topics = @user.topics.approved.tally.sort_by(&:last).reverse.map(&:first)
    @events = @user.events.includes(:organisation).distinct.order(start_date: :desc)
    @events_with_stickers = @events.select(&:sticker?)
    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }

    # Group events by country for the map tab
    @countries_with_events = @events.map { |event|
      country = event.static_metadata&.country
      [country, @events.select { |e| e.static_metadata&.country == country }] if country
    }.compact.uniq(&:first).sort_by { |country, _| country.translations["en"] }

    @back_path = speakers_path

    set_meta_tags(@user)
  end

  # GET /profiles/:slug/edit
  def edit
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

  private

  helper_method :user_kind
  def user_kind
    return params[:user_kind] if params[:user_kind].present? && Rails.env.development?
    return :admin if Current.user&.admin?
    return :owner if @user.managed_by?(Current.user)
    return :signed_in if Current.user.present?

    :anonymous
  end

  def set_user
    @user = User.includes(:talks).find_by(slug: params[:slug])

    # When the user is found from its slug, but the github handle is different, we need to redirect to the github handle
    if @user.present? && @user.github_handle.present? && @user.github_handle != params[:slug]
      return redirect_to profile_path(@user.github_handle), status: :moved_permanently
    end

    @user = User.includes(:talks).find_by(github_handle: params[:slug]) unless @user.present?

    redirect_to speakers_path, status: :moved_permanently, notice: "User not found" if @user.blank?
    redirect_to profile_path(@user.canonical) if @user&.canonical.present?
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
      :speakerdeck,
      :pronouns_type,
      :pronouns,
      :slug
    )
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
