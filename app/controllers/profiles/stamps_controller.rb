class Profiles::StampsController < ApplicationController
  include ProfileData

  def index
    @stamps = Stamp.for_user(@user)
  end
end
