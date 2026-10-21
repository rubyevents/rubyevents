# frozen_string_literal: true

module Static
  class Schedule < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/schedule.yml"

    schema ScheduleSchema

    belongs_to :event
    has_one :series, through: :event
  end
end
