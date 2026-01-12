# frozen_string_literal: true

class CoordinatesSchema < RubyLLM::Schema
  number :latitude, description: "Latitude coordinate"
  number :longitude, description: "Longitude coordinate"
end
