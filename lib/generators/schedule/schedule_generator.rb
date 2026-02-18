# frozen_string_literal: true

require "generators/event_base"

class ScheduleGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :break_duration, type: :numeric, desc: "The duration of breaks between talks in minutes", default: 15, group: "Fields"
  class_option :days, type: :array, desc: "The days of the event in YYYY-MM-DD format (e.g. 2024-09-01)", group: "Fields"
  class_option :day_start, type: :string, desc: "The start time of each day in HH:MM format (e.g. 08:00)", default: "08:00", group: "Fields"
  class_option :slots, type: :numeric, desc: "The number of concurrent talks per time slot", default: 1, group: "Fields"
  class_option :talk_duration, type: :numeric, desc: "The duration of each talk in minutes", default: 30, group: "Fields"
  class_option :videos_count, type: :numeric, desc: "The total number of videos to schedule - will be fetched from videos.yml if not provided", group: "Fields"

  def initialize_values
    event = Static::Event.find_by_slug options[:event]
    start_date = event.start_date
    end_date = event.end_date
    @days = options[:days] || (start_date..end_date).to_a
    @day_start = Time.parse(options[:day_start])
    videos_count = options[:videos_count] || Static::Video.where_event_slug(options[:event]).count
    @talks_per_half_day = (videos_count / (@days.size * 2)).ceil
  end

  def create_schedule_file
    template "schedule.yml.tt", File.join(destination_root, "data", options[:event_series], options[:event], "schedule.yml")
  end
end
