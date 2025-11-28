class Profiles::ConnectController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    redirect_to root_path, notice: "No profile here"
  end

  def show
    @connect_id = params[:id]
    @found_account = ConnectedAccount.find_by(uid: @connect_id, provider: "passport")
    @found_user = @found_account&.user

    if current_user_passport?
      # The user landed on their own connect page
      redirect_to profile_path(Current.user), notice: "You did it. You landed on your profile page 🙌"
    elsif passport_already_claimed?
      redirect_to profile_path(@found_user)
    end
  end

  private

  def current_user_passport?
    return false unless @connect_id.present?

    Current.user&.passports&.pluck(:uid)&.include?(@connect_id)
  end

  def passport_already_claimed?
    return false unless @connect_id.present?

    ConnectedAccount.passport.exists?(uid: @connect_id)
  end
end
