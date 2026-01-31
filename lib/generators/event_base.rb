require "rails/generators"

module Generators
  class EventBase < Rails::Generators::Base
    class_option :event_series, type: :string, desc: "Event series folder name", required: true, group: "Fields"
    class_option :event, type: :string, desc: "Event folder name", required: true, aliases: ["-e"], group: "Fields"

    GeocodedAddress = Struct.new(:street_address, :city, :state, :postal_code, :country, :country_code, :latitude, :longitude)

    private

    def geocode_address(name:, address:)
      if address != "123 TODO St, City, State, ZIP, Country" || name != "TODO Venue name"
        # Combine venue name and address for better accuracy
        search = [name, address].compact.join(", ")
        geocode_results = Geocoder.search(search)
        # Nominatim works better with separate queries - doesn't find the combined one
        geocode_results = Geocoder.search(address) if geocode_results.empty?
        geocode_results = Geocoder.search(name) if geocode_results.empty?
        # Nominatim works better with just the street address
        geocode_results = Geocoder.search(address.split(",")[0]) if geocode_results.empty?
      end

      geocode_results&.first || GeocodedAddress.new(
        street_address: "123 Main St",
        city: "City",
        state: "State",
        postal_code: "ZIP",
        country: "Country",
        country_code: "CC",
        latitude: 0.0,
        longitude: 0.0
      )
    end
  end
end
