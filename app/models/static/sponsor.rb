# frozen_string_literal: true

module Static
  class Sponsor < Yerba::Record::Base
    self.glob = "**/sponsors.yml"
    self.base_path = Rails.root.join("data")
    self.flatten = true

    schema SponsorsSchema

    belongs_to :event
    has_one :series, through: :event

    has_many :tiers, nested: true, class_name: "Static::Sponsor::Tier"
  end
end
