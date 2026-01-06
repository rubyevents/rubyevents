module Events
  class YearsController < ApplicationController
    skip_before_action :authenticate_user!, only: %i[index]

    def index
      @year = params[:year].to_i

      base_scope = Event.not_meetup.canonical
      first_year = base_scope.minimum(:start_date)&.year || Date.today.year
      last_year = base_scope.maximum(:start_date)&.year || Date.today.year

      if @year < first_year || @year > last_year
        redirect_to events_path, alert: "Invalid year" and return
      end

      @events = Event.includes(:series, :keynote_speakers)
        .not_meetup
        .canonical
        .where(start_date: Date.new(@year).all_year)
        .order(start_date: :asc)

      @monthly_events = @events.reject { |e| e.date_precision == "year" }
      @yearly_events = @events.select { |e| e.date_precision == "year" }
      @events_by_month = @monthly_events.group_by { |e| e.start_date&.month }

      @has_previous_year = @year > first_year
      @has_next_year = @year < last_year
    end
  end
end
