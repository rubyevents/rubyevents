class SpeakersController < ApplicationController
  skip_before_action :authenticate_user!
  include Pagy::Backend

  SORTS = %w[name talks recent].freeze

  # GET /speakers
  def index
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : "name"
    @speakers = sorted_speakers
    @speakers = @speakers.where("lower(users.name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @speakers = @speakers.ft_search(params[:s]).with_snippets.ranked if params[:s].present?
    @pagy, @speakers = pagy(@speakers, gearbox_extra: true, gearbox_limit: [200, 300, 600], page: params[:page])

    respond_to do |format|
      format.html do
        @activity = User::SpeakingActivity.for(@speakers)
        @directory = SpeakersDirectory.new if show_highlights?
      end
      format.turbo_stream { @activity = User::SpeakingActivity.for(@speakers) }
      format.json
    end
  end

  private

  helper_method def show_highlights?
    params[:s].blank? && params[:letter].blank?
  end

  def sorted_speakers
    case @sort
    when "talks" then User.speakers.where.not(name: Talk::StaticID::PLACEHOLDER_SPEAKER).order(talks_count: :desc)
    when "recent" then User.speakers.recently_active
    else User.speakers.order("LOWER(users.name)")
    end
  end
end
