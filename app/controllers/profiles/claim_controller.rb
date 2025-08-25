class Profiles::ClaimController < ApplicationController
  def create
    connected_account = ConnectedAccount.find_or_initialize_by(uid: params[:id], provider: "passport")

    if connected_account.new_record?
      connected_account.user = Current.user
      connected_account.save!

      redirect_to profiles_connect_path(id: params[:id]), notice: "Profile claimed successfully"
    else
      # Just in case there's a weird race condition, we'll redirect back to the connect page
      redirect_back fallback_location: profiles_connect_path(id: params[:id]), notice: "Profile already claimed"
    end
  end
end
