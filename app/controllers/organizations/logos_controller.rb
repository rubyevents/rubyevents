class Organizations::LogosController < ApplicationController
  before_action :set_organization
  before_action :ensure_admin!

  def show
    @back_path = organization_path(@organization)
  end

  def update
    if @organization.update(organization_params)
      redirect_to organization_logos_path(@organization), notice: "Updated successfully."
    else
      redirect_to organization_logos_path(@organization), alert: "Failed to update."
    end
  end

  private

  def set_organization
    @organization = Organization.find_by(slug: params[:organization_slug])
    redirect_to organizations_path, status: :moved_permanently, notice: "Organization not found" if @organization.blank?
  end

  def ensure_admin!
    redirect_to organizations_path, status: :unauthorized unless Current.user&.admin?
  end

  def organization_params
    params.require(:organization).permit(:logo_url, :logo_background)
  end
end
