# frozen_string_literal: true

module Static
  class Sponsor < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/sponsors.yml"
    self.flatten = true

    schema SponsorsSchema

    belongs_to :event
    has_one :series, through: :event

    has_many :tiers, nested: true, class_name: "Static::Sponsor::Tier"
  end
end
