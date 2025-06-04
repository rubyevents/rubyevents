class Events::SchedulesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show]
  before_action :set_event, only: %i[index show]

  def index
    @day = @days.first

    set_talks(@day)
  end

  def show
    @day = @days.find { |day| day["date"] == params[:date] }

    set_talks(@day)
  end

  private

  def set_event
    @event = Event.includes(organisation: :events).find_by!(slug: params[:event_slug])
    set_meta_tags(@event)

    @days = @event.schedule.days
    @tracks = @event.schedule.tracks

    redirect_to schedule_event_path(@event.canonical), status: :moved_permanently if @event.canonical.present?
    redirect_to event_path(@event), notice: "Event doesn't have a schedule" unless @event.schedule.exist?
  end

  def set_talks(day)
    raise "day blank with #{params[:date]}" if day.blank?

    index = @days.index(day)

    talk_count = @event.schedule.talk_offsets[index]
    talk_offset = @event.schedule.talk_offsets.first(index).sum

    @talks = @event.talks_in_running_order(child_talks: false).includes(:speakers).to_a.from(talk_offset).first(talk_count)
  end
end
