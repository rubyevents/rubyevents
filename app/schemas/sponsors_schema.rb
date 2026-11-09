# frozen_string_literal: true

class SponsorsSchema < ApplicationSchema
  data_file "**/sponsors.yml", selector: "[]"

  array :tiers, description: "List of sponsorship tiers", required: true do
    object do
      string :name, description: "Sponsorship Tier Name", required: false
      string :description, description: "Description of the sponsorship tier", required: false
      integer :level, description: "Sponsorship level (lower number indicates higher level)", required: false
      array :sponsors, description: "List of sponsors in this tier", required: true do
        object do
          string :slug, description: "Slug of the organization in data/organizations.yml", required: true
          string :badge, description: "Sponsor badge text", required: false
          string :from, description: "When the sponsorship started (YYYY, YYYY-MM or YYYY-MM-DD), for a series' sponsors.yml", required: false, pattern: InvolvementSchema::PERIOD_PATTERN
          string :to, description: "When the sponsorship ended (YYYY, YYYY-MM or YYYY-MM-DD), for a series' sponsors.yml, omitted while it lasts", required: false, pattern: InvolvementSchema::PERIOD_PATTERN
        end
      end
    end
  end
end
