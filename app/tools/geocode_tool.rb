# frozen_string_literal: true

class GeocodeTool < RubyLLM::Tool
  description "Geocode a location string (address, city, venue name) to get coordinates and address details using Google Maps."
  param :location, desc: "Location to geocode (e.g., 'Rimini, Italy', 'Hotel Ambasciatori, Rimini', 'Viale Vespucci 22, 47921 Rimini')"

  def execute(location:)
    return {error: "Location is required"} if location.blank?

    results = Geocoder.search(location)

    if results.empty?
      return {error: "No results found for '#{location}'"}
    end

    result = results.first

    {
      coordinates: {
        latitude: result.latitude,
        longitude: result.longitude
      },
      address: {
        formatted: result.respond_to?(:formatted_address) ? result.formatted_address : result.address,
        street: result.street_address,
        city: result.city,
        state: result.state,
        postal_code: result.postal_code,
        country: result.country,
        country_code: result.country_code
      },
      place_id: result.place_id,
      maps: {
        google: "https://www.google.com/maps/search/?api=1&query=#{result.latitude},#{result.longitude}",
        openstreetmap: "https://www.openstreetmap.org/?mlat=#{result.latitude}&mlon=#{result.longitude}&zoom=17"
      }
    }
  rescue => e
    {error: e.message}
  end
end
