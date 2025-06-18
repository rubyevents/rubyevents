class CallForPapersController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /events
  def index
    @events = Event.where(call_for_papers_deadline: Date.today..).order(call_for_papers_deadline: :asc)
  end
end
