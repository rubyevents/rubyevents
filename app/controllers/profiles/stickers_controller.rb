class Profiles::StickersController < ApplicationController
  include ProfileData

  def index
    @events = @user.participated_events.includes(:organisation)
    @events_with_stickers = @events.select(&:sticker?)
  end
end
