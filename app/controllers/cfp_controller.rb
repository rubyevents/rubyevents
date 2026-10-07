class CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /cfp
  def index
    cfps = CFP.includes(:event).open.order(CFP.arel_table[:close_date].asc.nulls_last)

    if params[:kind].present? && params[:kind] != "all"
      cfps = cfps.joins(:event).where(events: {kind: params[:kind]})
    end

    respond_to do |format|
      format.html do
        @events = cfps.map(&:event).group_by(&:kind).values.flatten
      end
      format.ics do
        calendar = Icalendar::Calendar.new

        cfps.with_dates.each do |cfp|
          calendar.add_event(cfp.to_ical)
        end

        render plain: calendar.to_ical
      end
    end
  end
end
