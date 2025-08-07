class ProfilesController < ApplicationController
  skip_before_action :authenticate_user!

  def connect
    @connect_id = params[:id]
    @found_user = User.find_by(connect_id: @connect_id)
  end
end
