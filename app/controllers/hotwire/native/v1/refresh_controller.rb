class Hotwire::Native::V1::RefreshController < ApplicationController
  skip_before_action :authenticate_user!

  def show
  end
end
