# frozen_string_literal: true

class CoordinatesSchema < ApplicationSchema
  number :latitude, description: "Latitude coordinate"
  number :longitude, description: "Longitude coordinate"
end
