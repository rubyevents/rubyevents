class Sponsors::LogosController < ApplicationController
  before_action :set_sponsor
  before_action :ensure_admin!

  def show
    @back_path = sponsor_path(@sponsor)
  end

  def update
    if @sponsor.update(sponsor_params)
      redirect_to sponsor_logos_path(@sponsor), notice: "Updated successfully."
    else
      redirect_to sponsor_logos_path(@sponsor), alert: "Failed to update."
    end
  end

  private

  def set_sponsor
    @sponsor = Sponsor.find_by(slug: params[:sponsor_slug])
    redirect_to sponsors_path, status: :moved_permanently, notice: "Sponsor not found" if @sponsor.blank?
  end

  def ensure_admin!
    redirect_to sponsors_path, status: :unauthorized unless Current.user&.admin?
  end

  def sponsor_params
    params.require(:sponsor).permit(:logo_url, :logo_background)
  end
end
