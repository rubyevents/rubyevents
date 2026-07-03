# frozen_string_literal: true

class CFPSchema < RubyLLM::Schema
  string :link, description: "CFP link", required: true
  string :name, description: 'Name for the CFP (default: "Call for Proposals")', required: false
  string :open_date, description: "CFP open date (YYYY-MM-DD format)", required: false
  string :close_date, description: "CFP close date (YYYY-MM-DD format)", required: false
end
