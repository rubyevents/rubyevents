# frozen_string_literal: true

class LocationSchema < RubyLLM::Schema
  string :name, description: "Location name"
  string :kind, description: "Type of location (e.g., 'After Party Location')"
  string :description, description: "Location description", required: false
  object :address, of: AddressSchema, description: "Location address", required: false
  string :distance, description: "Distance from main venue", required: false
  string :url, description: "Location website URL", required: false
  object :coordinates, of: CoordinatesSchema
  object :maps, of: MapsSchema, required: false
end
