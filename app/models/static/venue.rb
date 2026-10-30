# frozen_string_literal: true

module Static
  class Venue < Yerba::Record::Base
    self.path = "data/*parent_path/:series_id/:event_id/venue.yml"
    self.skipped_beside = "series.yml"

    schema VenueSchema

    belongs_to :event
    has_one :series, through: :event
  end
end
