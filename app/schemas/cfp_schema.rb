# frozen_string_literal: true

class CFPSchema < ApplicationSchema
  data_file "**/cfp.yml", selector: "[]"

  string :link, description: "CFP link", required: true
  string :name, description: 'Name for the CFP (default: "Call for Proposals")', required: false
  string :open_date, description: "CFP open date (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
  string :close_date, description: "CFP close date (YYYY-MM-DD format)", required: false, pattern: "^\\d{4}-\\d{2}-\\d{2}$"
end
