class Hotwire::Native::V1::AuthController < ApplicationController
  layout false

  skip_before_action :authenticate_user!

  def show
    @provider = params[:provider]
    @redirect_to = params[:redirect_to]
    @state = params[:state]
  end
end
