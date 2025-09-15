class Talks::RecommendationsController < ApplicationController
  include WatchedTalks

  skip_before_action :authenticate_user!
  before_action :set_talk, only: %i[index]

  def index
    redirect_to talk_path(@talk) unless turbo_frame_request?
    @talks = @talk&.related_talks || []
    fresh_when(@talks)
  end

  private

  def set_talk
    @talk = Talk.find_by(slug: params[:talk_slug])
  end
end
