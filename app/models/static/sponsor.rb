# frozen_string_literal: true

module Static
  class Sponsor < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/sponsors.yml"
    self.flatten = true

    schema do
      array :tiers, description: "List of sponsorship tiers", required: true do
        object do
          string :name, description: "Sponsorship Tier Name", required: false
          string :description, description: "Description of the sponsorship tier", required: false
          integer :level, description: "Sponsorship level (lower number indicates higher level)", required: false
          array :sponsors, description: "List of sponsors in this tier", required: true do
            object do
              string :name, description: "Sponsor Name", required: true
              string :slug, description: "Sponsor identifier slug", required: true
              string :website, description: "Sponsor's website URL", required: true
              string :description, description: "Description of the sponsor", required: false
              string :logo_url, description: "URL to the sponsor's logo image", required: false
              string :badge, description: "Sponsor badge text", required: false
            end
          end
        end
      end
    end

    belongs_to :event
    has_one :series, through: :event

    has_many :tiers, nested: true, class_name: "Static::Sponsor::Tier"
  end
end
