# frozen_string_literal: true

class MapsSchema < RubyLLM::Schema
  string :google, description: "Google Maps URL", required: false
  string :apple, description: "Apple Maps URL", required: false
  string :openstreetmap, description: "OpenStreetMap URL", required: false
end
