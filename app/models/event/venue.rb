class Event::Venue < ActiveRecord::AssociatedObject
  include YAMLFile

  yaml_file "venue.yml"

  extension do
    def geocode
      if venue.exist? && venue.coordinates.present?
        coords = venue.coordinates
        self.latitude = coords["latitude"]
        self.longitude = coords["longitude"]
      end

      super
    end
  end

  def name
    file["name"]
  end

  def slug
    file["slug"]
  end

  def description
    file["description"]
  end

  def address
    file["address"] || {}
  end

  def display_address
    address["display"]
  end

  def street
    address["street"]
  end

  def city
    address["city"]
  end

  def region
    address["region"]
  end

  def postal_code
    address["postal_code"]
  end

  def country
    address["country"]
  end

  def country_code
    address["country_code"]
  end

  def coordinates
    file["coordinates"] || {}
  end

  def latitude
    coordinates["latitude"]
  end

  def longitude
    coordinates["longitude"]
  end

  def maps
    file["maps"] || {}
  end

  def google_maps_url
    maps["google"]
  end

  def apple_maps_url
    maps["apple"]
  end

  def openstreetmap_url
    maps["openstreetmap"]
  end

  def instructions
    file["instructions"]
  end

  def url
    file["url"]
  end

  def accessibility
    file["accessibility"] || {}
  end

  def rooms
    file["rooms"] || []
  end

  def spaces
    file["spaces"] || []
  end

  def nearby
    file["nearby"] || {}
  end

  def hotels
    file["hotels"] || []
  end

  def locations
    file["locations"] || []
  end

  def map_markers
    markers = []

    if latitude.present? && longitude.present?
      markers << {
        latitude: latitude,
        longitude: longitude,
        kind: "venue",
        name: name,
        address: display_address
      }
    end

    hotels.each do |hotel|
      coords = hotel["coordinates"]
      next unless coords&.dig("latitude").present? && coords&.dig("longitude").present?

      markers << {
        latitude: coords["latitude"],
        longitude: coords["longitude"],
        kind: "hotel",
        name: hotel["name"],
        address: hotel["address"],
        distance: hotel["distance"]
      }
    end

    locations.each do |location|
      coords = location["coordinates"]
      next unless coords&.dig("latitude").present? && coords&.dig("longitude").present?

      markers << {
        latitude: coords["latitude"],
        longitude: coords["longitude"],
        kind: "location",
        name: location["name"],
        location_kind: location["kind"],
        address: location["address"],
        distance: location["distance"]
      }
    end

    markers
  end
end
