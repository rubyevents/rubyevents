class TalksController < ApplicationController
  include RemoteModal
  include Pagy::Backend
  include WatchedTalks

  skip_before_action :authenticate_user!

  respond_with_remote_modal only: [:edit]

  before_action :set_talk, only: %i[show edit update]
  before_action :set_user_favorites, only: %i[index show]

  ORDER_BY_OPTIONS = {
    "date_desc" => "talks.date DESC",
    "date_asc" => "talks.date ASC",
    "created_at_desc" => "talks.created_at DESC",
    "created_at_asc" => "talks.created_at ASC"
  }.freeze

  # GET /talks
  def index
    @talks = Talk.includes(:speakers, event: :series, child_talks: :speakers)
    @talks = @talks.ft_search(params[:s]).with_snippets if params[:s].present?
    @talks = @talks.for_topic(params[:topic]) if params[:topic].present?
    @talks = @talks.for_event(params[:event]) if params[:event].present?
    @talks = @talks.for_speaker(params[:speaker]) if params[:speaker].present?
    @talks = @talks.where(kind: talk_kind) if talk_kind.present?
    @talks = @talks.where("created_at >= ?", created_after) if created_after
    @talks = @talks.watchable if params[:status].blank? && params[:status] != "all"
    @talks = @talks.scheduled if params[:status] == "scheduled"

    # Apply ordering (handles search ranking vs custom ordering)
    if order_by_key == "ranked"
      @talks = @talks.ranked
    elsif order_by_key.present?
      @talks = @talks.order(ORDER_BY_OPTIONS[order_by_key])
    end

    @pagy, @talks = pagy(@talks, **pagy_params)
  end

  # GET /talks/1
  def show
    set_meta_tags(@talk)
  end

  # GET /talks/1/edit
  def edit
    set_modal_options(size: :lg)
  end

  # PATCH/PUT /talks/1
  def update
    suggestion = @talk.create_suggestion_from(params: talk_params, user: Current.user)
    if suggestion.persisted?
      redirect_to @talk, notice: suggestion.notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  helper_method :order_by_key
  def order_by_key
    if params[:s].present? && !explicit_ordering_requested?
      return "ranked"
    end

    params[:order_by].presence_in(ORDER_BY_OPTIONS.keys) || "date_desc"
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

  def pagy_params
    {
      limit: params[:limit]&.to_i,
      page: params[:page]&.to_i
    }.compact_blank
  end

  def talk_kind
    @talk_kind ||= params[:kind].presence_in(Talk.kinds.keys)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_talk
    @talk = Talk.includes(:approved_topics, :speakers, event: :series, watched_talks: :user).find_by(slug: params[:slug])
    @talk ||= Talk.find_by_slug_or_alias(params[:slug])

    return redirect_to talks_path, status: :moved_permanently if @talk.blank?

    redirect_to talk_path(@talk), status: :moved_permanently if @talk.slug != params[:slug]
  end

  # Only allow a list of trusted parameters through.
  def talk_params
    params.require(:talk).permit(:title, :description, :summarized_using_ai, :summary, :date, :slides_url)
  end

  helper_method :search_params
  def search_params
    params.permit(:s, :topic, :event, :speaker, :kind, :created_after, :all, :order_by, :status)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
