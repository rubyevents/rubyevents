class Profiles::EnhanceController < ApplicationController
  def update
    @user = User.find_by(slug: params[:slug])

    @user.profiles.enhance_all_later

    flash.now[:notice] = "Profile will be updated soon."

    respond_to do |format|
      format.turbo_stream
    end
  end
end
