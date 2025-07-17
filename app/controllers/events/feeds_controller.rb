class Events::FeedsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @events = Event.order(date: :desc).limit(20)

    respond_to do |format|
      format.xml
    end
  end
end
