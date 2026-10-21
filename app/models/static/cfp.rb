# frozen_string_literal: true

module Static
  class CFP < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/cfp.yml"
    self.flatten = true

    schema do
      string :link, description: "CFP link", required: true
      string :name, description: 'Name for the CFP (default: "Call for Proposals")', required: false
      string :open_date, description: "CFP open date (YYYY-MM-DD format)", required: false
      string :close_date, description: "CFP close date (YYYY-MM-DD format)", required: false
    end

    belongs_to :event
    has_one :series, through: :event
  end
end
