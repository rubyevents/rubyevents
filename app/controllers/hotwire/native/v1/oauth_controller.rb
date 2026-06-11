class Hotwire::Native::V1::OauthController < ApplicationController
  skip_before_action :authenticate_user!

  def show
  end
end
