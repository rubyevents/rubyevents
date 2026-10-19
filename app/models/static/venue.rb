# frozen_string_literal: true

module Static
  class Venue < Yerba::Record::Base
    self.path = "data/:series_id/:event_id/venue.yml"

    schema VenueSchema

    belongs_to :event
    has_one :series, through: :event
  end
end
