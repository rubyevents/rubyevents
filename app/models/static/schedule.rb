# frozen_string_literal: true

module Static
  class Schedule < Yerba::Record::Base
    self.glob = "**/schedule.yml"
    self.base_path = Rails.root.join("data")

    schema ScheduleSchema

    belongs_to :event
  end
end
