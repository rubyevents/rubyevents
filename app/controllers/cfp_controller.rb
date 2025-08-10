class CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /cfp
  def index
    @events = Event.where(cfp_close_date: Date.today..).order(cfp_close_date: :asc)
  end
end
