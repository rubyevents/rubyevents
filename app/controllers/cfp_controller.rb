class CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /cfp
  def index
    @events = CFP.includes(:event).open.order(cfps: {close_date: :asc}).map(&:event)
  end
end
