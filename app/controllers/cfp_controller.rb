class CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /cfp
  def index
    @events = Event.includes(:cfps).where(cfps: {close_date: Date.today..}).order(cfps: {close_date: :asc})
  end
end
