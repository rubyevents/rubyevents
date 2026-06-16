class SessionsController < ApplicationController
  include RemoteModal

  respond_with_remote_modal only: [:new]

  skip_before_action :authenticate_user!, only: %i[new create exchange]

  def new
    @user = User.new
    # Add connect_id or connect_to to state if present
    @state = "connect_id:#{params[:connect_id]}" if params[:connect_id].present?
    @state = "connect_to:#{params[:connect_to]}" if params[:connect_to].present?
  end

  def create
    user = User.authenticate_by(params.permit(:email, :password))

    if user
      sign_in user
      redirect_to root_path, notice: "Signed in successfully"
    else
      redirect_to new_session_path(email_hint: params[:email]), alert: "That email or password is incorrect"
    end
  end

  def exchange
    user = User.find_signed(params[:token], purpose: :native_signin)

    if user
      sign_in user
      redirect_to hotwire_native_v1_refresh_path, notice: "Signed in successfully"
    else
      redirect_to new_session_path, alert: "Sign-in link expired. Please try again."
    end
  end

  def destroy
    Current.user.sessions.destroy_by(id: params[:id])
    redirect_to (hotwire_native_app? ? hotwire_native_v1_refresh_path : root_path), notice: "That session has been logged out"
  end
end
