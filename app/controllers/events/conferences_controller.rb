class Events::ConferencesController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @events = Event.for_conference_feed

    respond_to do |format|
      format.rss { render layout: false }
    end
  end
end
