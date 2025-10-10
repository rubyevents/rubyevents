class Profiles::ClaimsController < ApplicationController
  def create
    connected_account = Current.user.connected_accounts.find_or_create_by(uid: params[:id], provider: "passport")

    flash[:notice] = connected_account.previously_new_record? ? "Profile claimed successfully" : "Profile already claimed"
    redirect_to profile_path(Current.user)
  end
end
