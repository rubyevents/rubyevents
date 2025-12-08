class Profiles::EnhanceController < ApplicationController
  def update
    @user = User.find_by_slug_or_alias(params[:slug])
    @user ||= User.find_by_github_handle(params[:slug])

    @user.profiles.enhance_all_later

    flash.now[:notice] = "Profile will be updated soon."

    respond_to do |format|
      format.turbo_stream
    end
  end
end
