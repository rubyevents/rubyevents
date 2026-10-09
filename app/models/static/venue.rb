# frozen_string_literal: true

module Static
  class Venue < Yerba::Record::Base
    self.glob = "**/venue.yml"
    self.base_path = Rails.root.join("data")

    schema VenueSchema

    belongs_to :event
  end
end
