class SpeakersController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_speaker, only: %i[show]
  include Pagy::Backend

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
    redirect_to profile_path(@speaker), status: :moved_permanently
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
    @speaker = User.find_by(slug: params[:slug])

    redirect_to speakers_path, status: :moved_permanently, notice: "Speaker not found" if @speaker.blank?
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
