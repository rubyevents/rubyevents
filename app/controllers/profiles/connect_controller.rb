class Profiles::ConnectController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    redirect_to root_path
  end

  def show
    @connect_id = params[:id]
    @found_account = ConnectedAccount.find_by(uid: @connect_id, provider: "passport")
    @found_user = @found_account&.user

    # The user landed on their own connect page
    if Current.user && Current.user.passport_account.present? && Current.user.passport_account == @found_account
      # This should probably redirect to the profile page when we have one
      redirect_to root_path, notice: "You did it. You landed on your profile page 🙌"
    end
  end
end
