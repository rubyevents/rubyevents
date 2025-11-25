class SpeakersController < ApplicationController
  skip_before_action :authenticate_user!
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
end
