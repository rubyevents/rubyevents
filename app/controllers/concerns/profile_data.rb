module ProfileData
  extend ActiveSupport::Concern

  included do
    skip_before_action :authenticate_user!
    before_action :set_user
    before_action :set_favorite_user
    before_action :set_user_favorites
    before_action :set_mutual_events
    before_action :load_common_data
    include WatchedTalks

    helper_method :user_kind
  end

  def load_common_data
    @talks = @user.kept_talks
    @events = @user.participated_events
    @stamps = Stamp.for_user(@user)
    @events_with_stickers = @events.select(&:sticker?)
    @involvements_by_role = @user.event_involvements.group_by(&:role).transform_values(&:any?)
    @countries_with_events = @events.group_by(&:country_code).any? ? [true] : []
    @topics = @user.topics.approved.tally.sort_by(&:last).reverse.map(&:first)
    @aliases = Current.user&.admin? ? @user.aliases : []
    @back_path = speakers_path
  end

  private

  def set_user
    @user = User.includes(:talks, :passports).find_by(slug: params[:profile_slug])
    @user = User.includes(:talks).find_by_github_handle(params[:profile_slug]) unless @user.present?

    redirect_to speakers_path, status: :moved_permanently, notice: "User not found" if @user.blank?
    redirect_to profile_path(@user.canonical) if @user&.canonical.present?
  end

  def set_favorite_user
    @favorite_user = FavoriteUser.find_by(user: Current.user, favorite_user: @user)
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

  def user_kind
    return params[:user_kind] if params[:user_kind].present? && Rails.env.development?
    return :admin if Current.user&.admin?
    return :owner if @user.managed_by?(Current.user)
    return :signed_in if Current.user.present?

    :anonymous
  end
end
