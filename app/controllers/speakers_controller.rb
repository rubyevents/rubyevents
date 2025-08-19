class SpeakersController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_speaker, only: %i[show edit update]
  before_action :set_user_favorites, only: %i[show]
  include Pagy::Backend
  include RemoteModal
  include WatchedTalks
  respond_with_remote_modal only: [:edit]

  # GET /speakers
  def index
    @speakers = User.speakers.order(:name)
    @speakers = @speakers.with_talks unless params[:with_talks] == "false"
    # @speakers = @speakers.canonical unless params[:canonical] == "false"
    @speakers = @speakers.where("lower(name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @speakers = @speakers.ft_search(params[:s]).with_snippets.ranked if params[:s].present?
    @pagy, @speakers = pagy(@speakers, gearbox_extra: true, gearbox_limit: [200, 300, 600], page: params[:page])
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
    end
  end

  # GET /speakers/1
  def show
    @talks = @speaker.kept_talks.includes(:speakers, event: :organisation, child_talks: :speakers).order(date: :desc)
    @talks_by_kind = @talks.group_by(&:kind)
    @topics = @speaker.topics.approved.tally.sort_by(&:last).reverse.map(&:first)
    @events = @speaker.events.includes(:organisation).distinct.order(start_date: :desc)
    @events_with_stickers = @events.select(&:sticker?)
    @events_by_year = @events.group_by { |event| event.start_date&.year || "Unknown" }

    # Group events by country for the map tab
    @countries_with_events = @events.map { |event|
      country = event.static_metadata&.country
      [country, @events.select { |e| e.static_metadata&.country == country }] if country
    }.compact.uniq(&:first).sort_by { |country, _| country.translations["en"] }

    @back_path = speakers_path

    set_meta_tags(@speaker)
  end

  # GET /speakers/1/edit
  def edit
  end

  # PATCH/PUT /speakers/1
  def update
    suggestion = @speaker.create_suggestion_from(params: speaker_params, user: Current.user)
    if suggestion.persisted?
      redirect_to speaker_path(@speaker), notice: suggestion.notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  helper_method :user_kind
  def user_kind
    return params[:user_kind] if params[:user_kind].present? && Rails.env.development?
    return :admin if Current.user&.admin?
    return :owner if @speaker.managed_by?(Current.user)
    return :signed_in if Current.user.present?

    :anonymous
  end

  def set_speaker
    @speaker = User.includes(:talks).find_by(slug: params[:slug])

    redirect_to speakers_path, status: :moved_permanently, notice: "Speaker not found" if @speaker.blank?
    redirect_to speaker_path(@speaker.canonical) if @speaker&.canonical.present?
  end

  def speaker_params
    params.require(:speaker).permit(
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
