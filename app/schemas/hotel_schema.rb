# frozen_string_literal: true

class HotelSchema < RubyLLM::Schema
  string :name, description: "Hotel name"
  string :kind, description: "Type of hotel (e.g., 'Speaker Hotel')", required: false
  string :description, description: "Hotel description", required: false
  object :address, of: AddressSchema, description: "Hotel address"
  string :url, description: "Hotel website URL", required: false
  string :distance, description: "Distance from venue", required: false
  object :coordinates, of: CoordinatesSchema
  object :maps, of: MapsSchema, required: false
end
