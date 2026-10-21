class Profiles::StickersController < ApplicationController
  include ProfileData

  def index
    @events = @user.attended_events.includes(:series)
    @stickers = Static::Sticker.for_user(@user, events: @events)
  end
end
