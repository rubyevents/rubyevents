# frozen_string_literal: true

class MapsSchema < ApplicationSchema
  string :google, description: "Google Maps URL", required: false
  string :apple, description: "Apple Maps URL", required: false
  string :openstreetmap, description: "OpenStreetMap URL", required: false
end
