# frozen_string_literal: true

module Static
  class Schedule
    class Day < Yerba::Record::Base
      has_many :grid, nested: true, class_name: "Static::Schedule::Row"
    end
  end
end
