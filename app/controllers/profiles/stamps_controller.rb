class Profiles::StampsController < ApplicationController
  include ProfileData

  def index
    @stamps = Static::Stamp.for_user(@user)
  end
end
