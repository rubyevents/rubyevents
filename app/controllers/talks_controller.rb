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
    @talks = Talk.includes(:speakers, event: :organisation, child_talks: :speakers)
    @talks = @talks.watchable unless params[:all].present?
    @talks = @talks.ft_search(params[:s]).with_snippets.ranked if params[:s].present?
    @talks = @talks.for_topic(params[:topic]) if params[:topic].present?
    @talks = @talks.for_event(params[:event]) if params[:event].present?
    @talks = @talks.for_speaker(params[:speaker]) if params[:speaker].present?
    @talks = @talks.where(kind: talk_kind) if talk_kind.present?
    @talks = @talks.where("created_at >= ?", created_after) if created_after
    @talks = @talks.order(order_by) if order_by
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

  def feed
    @talks = Talk.order(created_at: :desc).limit(20)
    respond_to do |format|
      format.xml
    end
  end

  private

  def order_by
    # when searching, don't order by date as the search results are already ordered by relevance
    # unless the user explicitly asks for it
    return if params[:s].present? && params[:order_by].blank?
    order_by_options = {
      "date_desc" => "talks.date DESC",
      "date_asc" => "talks.date ASC",
      "created_at_desc" => "talks.created_at DESC",
      "created_at_asc" => "talks.created_at ASC"
    }

    @order_by ||= begin
      order = params[:order_by].presence_in(order_by_options.keys) || "date_desc"

      order_by_options[order]
    end
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
    @talk = Talk.includes(:approved_topics, speakers: :user, event: :organisation).find_by(slug: params[:slug])

    redirect_to talks_path, status: :moved_permanently if @talk.blank?
  end

  # Only allow a list of trusted parameters through.
  def talk_params
    params.require(:talk).permit(:title, :description, :summarized_using_ai, :summary, :date, :slides_url)
  end

  def set_user_favorites
    return unless Current.user

    @user_favorite_talks_ids = Current.user.default_watch_list.talks.ids
  end
end
