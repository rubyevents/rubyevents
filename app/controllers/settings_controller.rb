class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  def update
    if Current.user.update(settings_params)
      redirect_to settings_path, notice: "Settings saved successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:feedback_enabled, :wrapped_public)
  end
end
