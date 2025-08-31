class Speakers::EnhanceController < ApplicationController
  def update
    @speaker = User.find_by(slug: params[:slug])

    @speaker.profiles.enhance_all_later

    flash[:notice] = "Speaker profile will be updated soon."

    respond_to do |format|
      format.turbo_stream
    end
  end
end
