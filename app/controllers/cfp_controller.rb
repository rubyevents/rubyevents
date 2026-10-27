class CFPController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  # GET /cfp
  def index
    cfps = CFP.includes(:event, event_series: :events).open.order(CFP.arel_table[:close_date].asc.nulls_last)

    if params[:kind].present? && params[:kind] != "all"
      cfps = cfps.left_joins(:event, :event_series).where(events: {kind: params[:kind]}).or(cfps.left_joins(:event, :event_series).where(event_series: {kind: params[:kind]}))
    end

    respond_to do |format|
      format.html do
        @events = cfps.filter_map(&:event).group_by(&:kind).values.flatten
        @series_with_cfps = cfps.filter_map(&:event_series).uniq
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
