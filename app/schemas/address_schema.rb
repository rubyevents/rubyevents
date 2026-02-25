# frozen_string_literal: true

class AddressSchema < RubyLLM::Schema
  string :street, description: "Street address"
  string :city, description: "City name"
  string :region, description: "State/Province/Region", required: false
  string :postal_code, description: "Postal/ZIP code", required: false
  string :country, description: "Country name"
  string :country_code, description: "ISO country code (e.g., 'US', 'CA', 'JP')"
  string :display, description: "Full formatted address for display"
end
