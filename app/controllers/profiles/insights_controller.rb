class Profiles::InsightsController < ApplicationController
  include ProfileData

  def show
    speaker_profile = Insights::SpeakerProfile.new(@user)
    @profile = speaker_profile.compute

    if @profile
      @summary = speaker_profile.cached_summary
      @talk_suggestions = speaker_profile.cached_talk_suggestions
    end

    respond_to do |format|
      format.html
      format.json { render json: @profile&.merge(summary: @summary, talk_suggestions: @talk_suggestions) }
    end
  end
end
