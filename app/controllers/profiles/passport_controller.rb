class Profiles::PassportController < ApplicationController
  include ProfileData

  def index
    @check_ins = @user.passport_check_ins
  end
end
