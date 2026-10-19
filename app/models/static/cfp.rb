# frozen_string_literal: true

module Static
  class CFP < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/cfp.yml"
    self.flatten = true

    schema CFPSchema

    belongs_to :event
    has_one :series, through: :event
  end
end
