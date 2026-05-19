# frozen_string_literal: true

class FeaturedCitySchema < RubyLLM::Schema
  string :name, description: "Full city name"
  string :slug, description: "URL-friendly slug for the city"
  string :state_code, description: "State or province code", required: false
  string :country_code, description: "ISO 3166-1 alpha-2 country code"
  number :latitude, description: "Geographic latitude"
  number :longitude, description: "Geographic longitude"
  array :aliases, of: :string, description: "Alternative names or abbreviations", required: false

  def to_json_schema
    result = super
    result[:schema][:properties][:state_code][:type] = ["string", "null"]
    result
  end
end
