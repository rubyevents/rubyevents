class Identity::EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  def show
    verification = User::EmailVerification.find_by_token(params[:sid])

    if verification
      verification.verify!
      redirect_to root_path, notice: "Thank you for verifying your email address"
    else
      redirect_to edit_identity_email_path, alert: "That email verification link is invalid"
    end
  end

  def create
    Current.user.email_verification.deliver_later
    redirect_to root_path, notice: "We sent a verification email to your email address"
  end
end
