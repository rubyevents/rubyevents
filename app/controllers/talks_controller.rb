class TalksController < ApplicationController
  include RemoteModal
  include Pagy::Backend
  include WatchedTalks

  skip_before_action :authenticate_user!

  respond_with_remote_modal only: [:edit]

  before_action :set_talk, only: %i[show edit update]
  before_action :set_user_favorites, only: %i[index show]

  # GET /talks
  def index
    @pagy, @talks = search_backend.search_talks_with_pagy(
      params[:s],
      pagy_backend: self,
      **search_options
    )
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

  def search_backend
    Search::Backend::SQLiteFTS
  end

  def search_options
    {
      per_page: params[:limit]&.to_i || 20,
      page: params[:page]&.to_i || 1,
      sort: sort_key,
      topic_slug: params[:topic],
      event_slug: params[:event],
      speaker_slug: params[:speaker],
      kind: talk_kind,
      language: params[:language],
      created_after: created_after,
      status: params[:status],
      include_unwatchable: params[:status] == "all"
    }.compact_blank
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

    redirect_to talk_path(@talk), status: :moved_permanently if @talk.slug != params[:slug]
  end

  # Only allow a list of trusted parameters through.
  def talk_params
    params.require(:talk).permit(:title, :description, :summarized_using_ai, :summary, :date, :slides_url)
  end

  helper_method :search_params
  def search_params
    params.permit(:s, :topic, :event, :speaker, :kind, :created_after, :all, :order_by, :status, :language)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
