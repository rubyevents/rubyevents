class Talks::ThumbnailsController < ApplicationController
  before_action :require_local_admin!

  PER_PAGE = 48

  def index
    scope = Talk.includes(:event, :speakers)
    scope = scope.joins(:event).where(events: {slug: params[:event]}) if params[:event].present?

    @variant = params[:variant].presence || "both"
    @variants = (@variant == "both") ? Talk::ThumbnailGenerator::VARIANTS : [@variant]

    @page = [params[:page].to_i, 1].max
    @total = scope.count
    @talks = scope.order(created_at: :desc).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @has_next = @page * PER_PAGE < @total
  end

  def show
    talk = Talk.find_by_slug_or_alias(params[:talk_slug])
    return head :not_found if talk.blank?

    path = Talk::ThumbnailGenerator.new(talk, variant: params[:variant].to_s).write_to_disk
    return head :unprocessable_entity if path.blank?

    send_file path, type: "image/png", disposition: "inline"
  end

  private

  def require_local_admin!
    head :not_found unless Rails.env.local? && Current.user&.admin?
  end
end
