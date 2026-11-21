class Talks::RecommendationsController < ApplicationController
  include WatchedTalks

  skip_before_action :authenticate_user!
  before_action :set_talk, only: %i[index]

  def index
    unless turbo_frame_request?
      return redirect_to(@talk ? talk_path(@talk) : talks_path, status: :moved_permanently)
    end

    @talks = @talk&.related_talks || []
    fresh_when(@talks)
  end

  private

  def set_talk
    @talk = Talk.find_by_slug_or_alias(params[:talk_slug])
  end
end
