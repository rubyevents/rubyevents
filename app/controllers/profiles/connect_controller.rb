class Profiles::ConnectController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    redirect_to root_path
  end

  def show
    @connect_id = params[:id]
    @found_user = User.find_by(connect_id: @connect_id)
  end
end
