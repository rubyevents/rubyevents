# frozen_string_literal: true

module Static
  class CFP < Yerba::Record::Base
    self.path = "data/*parent_path/:series_id/:event_id/cfp.yml"
    self.skipped_beside = "series.yml"
    self.flatten = true

    schema CFPSchema

    belongs_to :event
    has_one :series, through: :event
  end
end
