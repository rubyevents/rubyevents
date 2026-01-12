class CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /cfp
  def index
    cfps = CFP.includes(:event).open.order(cfps: {close_date: :asc})

    if params[:kind].present? && params[:kind] != "all"
      cfps = cfps.joins(:event).where(events: {kind: params[:kind]})
    end

    @events = cfps.map(&:event)
  end
end
