class PasswordsController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    if @user.update(password_params)
      Current.session.sign_out_siblings!
      redirect_to root_path, notice: "Your password has been changed"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def password_params
    params.permit(:password_challenge, :password, :password_confirmation)
  end
end
