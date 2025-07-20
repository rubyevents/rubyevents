class CallForPapersController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /call_for_papers
  def index
    @events = Event.where(cfp_close_date: Date.today..).order(cfp_close_date: :asc)
  end
end
