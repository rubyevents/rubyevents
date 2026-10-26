# frozen_string_literal: true

module Static
  class SeriesSponsor < Yerba::Record::Base
    self.path = "data/*parent_path/:event_series_id/sponsors.yml"
    self.sibling_file = "series.yml"
    self.flatten = true

    schema SponsorsSchema

    belongs_to :event_series
    has_many :tiers, nested: true, class_name: "Static::Sponsor::Tier"
  end
end
