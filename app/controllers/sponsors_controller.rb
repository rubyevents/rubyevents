class SponsorsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_sponsor, only: %i[show]
  include Pagy::Backend

  # GET /sponsors
  def index
    @sponsors = Sponsor.order(:name)
    @sponsors = @sponsors.where("lower(name) LIKE ?", "#{params[:letter].downcase}%") if params[:letter].present?
    @pagy, @sponsors = pagy(@sponsors, gearbox_extra: true, gearbox_limit: [200, 300, 600], page: params[:page])
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
    end
  end

  # GET /sponsors/1
  def show
    @back_path = sponsors_path
  end

  private

  def set_sponsor
    @sponsor = Sponsor.find_by(slug: params[:slug])
    
    redirect_to sponsors_path, status: :moved_permanently, notice: "Sponsor not found" if @sponsor.blank?
  end
end
