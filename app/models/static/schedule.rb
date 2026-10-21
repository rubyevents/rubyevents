# frozen_string_literal: true

module Static
  class Schedule < Yerba::Record::Base
    self.path = "data/*parent_path/:series_id/:event_id/schedule.yml"
    self.skipped_beside = "series.yml"

    schema ScheduleSchema

    belongs_to :event
    has_one :series, through: :event

    has_many :days, nested: true, class_name: "Static::Schedule::Day"

    validates_with Static::ScheduleSlotsValidator, on: :lint
    validates_with Static::ScheduleDuplicateTimeSlotsValidator

    def track_names
      Array(tracks).filter_map { |track| track["name"] }
    end
  end
end
