# frozen_string_literal: true

class InvolvementSchema < ApplicationSchema
  data_file "**/involvements.yml", selector: "[]"

  PERIOD_PATTERN = "^\\d{4}(-\\d{2}(-\\d{2})?)?$"

  string :name, description: "Role or involvement type (e.g., 'Organizer', 'Program Committee member')"

  array :users, description: "Person names involved in this role. In a series' involvements.yml, a name can carry the period it held the role", required: false do
    any_of do
      string
      object do
        string :name, description: "Person name"
        string :from, description: "When the role started (YYYY, YYYY-MM or YYYY-MM-DD)", required: false, pattern: PERIOD_PATTERN
        string :to, description: "When the role ended (YYYY, YYYY-MM or YYYY-MM-DD), omitted while it lasts", required: false, pattern: PERIOD_PATTERN
      end
    end
  end

  array :organizations, description: "Slugs of organizations (data/organizations.yml) involved in this role. In a series' involvements.yml, a slug can carry the period it held the role", required: false do
    any_of do
      string
      object do
        string :slug, description: "Organization slug"
        string :from, description: "When the role started (YYYY, YYYY-MM or YYYY-MM-DD)", required: false, pattern: PERIOD_PATTERN
        string :to, description: "When the role ended (YYYY, YYYY-MM or YYYY-MM-DD), omitted while it lasts", required: false, pattern: PERIOD_PATTERN
      end
    end
  end
end
