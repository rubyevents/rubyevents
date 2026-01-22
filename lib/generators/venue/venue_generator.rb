# frozen_string_literal: true

require "generators/event_base"

class VenueGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :name, type: :string, desc: "Venue name", default: "Venue name", group: "Fields"
  class_option :address, type: :string, desc: "Venue address", default: "123 Main St, City, State, ZIP, Country", group: "Fields"
  class_option :accessibility, type: :boolean, desc: "Include accessibility information section", default: true, group: "Fields"
  class_option :hotels, type: :boolean, desc: "Include hotel information section", default: false, group: "Fields"
  class_option :nearby, type: :boolean, desc: "Include nearby amenities section", default: false, group: "Fields"
  class_option :locations, type: :boolean, desc: "Include additional locations section", default: false, group: "Fields"
  class_option :rooms, type: :boolean, desc: "Include rooms section", default: false, group: "Fields"
  class_option :spaces, type: :boolean, desc: "Include spaces section", default: false, group: "Fields"

  GeocodedAddress = Struct.new(:street_address, :city, :state, :postal_code, :country, :country_code, :latitude, :longitude)

  def copy_venue_file
    geocode_address
    template "venue.yml.tt", File.join(["data", options[:event_series], options[:event], "venue.yml"])
  end

  def geocode_address
    if options[:address] != "123 Main St, City, State, ZIP, Country" || options[:name] != "Venue name"
      # Combine venue name and address for better accuracy
      search = [options[:name], options[:address]].compact.join(", ")
      geocode_results = Geocoder.search(search)
      # Nominatim works better with separate queries - doesn't find the combined one
      geocode_results = Geocoder.search(options[:address]) if geocode_results.empty?
      geocode_results = Geocoder.search(options[:name]) if geocode_results.empty?
      # Nominatim works better with just the street address
      geocode_results = Geocoder.search(options[:address].split(",")[0]) if geocode_results.empty?
    end

    @geocoded_address = geocode_results&.first ||
      GeocodedAddress.new(
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
