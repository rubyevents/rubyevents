class Talks::SlidesController < ApplicationController
  include Turbo::ForceResponse

  force_frame_response

  skip_before_action :authenticate_user!

  def show
    @talk = Talk.find_by(slug: params[:talk_slug])
  end
end
