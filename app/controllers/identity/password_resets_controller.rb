class Identity::PasswordResetsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_password_reset, only: %i[edit update]

  def new
  end

  def create
    reset = User::PasswordReset.find_by(params.permit(:email))

    if reset&.valid?
      reset.deliver_later
      redirect_to sign_in_path, notice: "Check your email for reset instructions"
    else
      redirect_to new_identity_password_reset_path, alert: "You can't reset your password until you verify your email"
    end
  end

  def edit
  end

  def update
    if @password_reset.reset(password_params)
      redirect_to sign_in_path, notice: "Your password was reset successfully. Please sign in"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_password_reset
    @password_reset = User::PasswordReset.find_by_token(params[:sid]) or
      redirect_to new_identity_password_reset_path, alert: "That password reset link is invalid"

    @user = @password_reset&.user
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
