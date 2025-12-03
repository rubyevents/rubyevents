# frozen_string_literal: true

class VenueSchema < RubyLLM::Schema
  string :name, description: "Name of the venue"
  string :description, description: "Description of the venue", required: false
  string :instructions, description: "Instructions for getting to the venue", required: false

  object :address, description: "Physical address of the venue", required: false do
    string :street, description: "Street address", required: false
    string :city, description: "City name", required: false
    string :region, description: "State/Province/Region", required: false
    string :postal_code, description: "Postal/ZIP code", required: false
    string :country, description: "Country name", required: false
    string :country_code, description: "ISO country code (e.g., 'US', 'CA')", required: false
    string :display, description: "Full formatted address for display", required: false
  end

  object :coordinates, description: "Geographic coordinates", required: false do
    number :latitude, description: "Latitude coordinate"
    number :longitude, description: "Longitude coordinate"
  end

  object :maps, description: "Links to various map services", required: false do
    string :google, description: "Google Maps URL", required: false
    string :apple, description: "Apple Maps URL", required: false
    string :openstreetmap, description: "OpenStreetMap URL", required: false
  end

  array :rooms, description: "Rooms within the venue", required: false do
    object do
      string :name, description: "Room name"
      string :floor, description: "Floor location", required: false
      integer :capacity, description: "Room capacity", required: false
      string :instructions, description: "Instructions for finding the room", required: false
    end
  end

  array :spaces, description: "Other spaces within the venue", required: false do
    object do
      string :name, description: "Space name"
      string :floor, description: "Floor location", required: false
      string :instructions, description: "Instructions for finding the space", required: false
    end
  end

  object :accessibility, description: "Accessibility information", required: false do
    boolean :wheelchair, description: "Wheelchair accessible", required: false
    boolean :elevators, description: "Elevators available", required: false
    boolean :accessible_restrooms, description: "Accessible restrooms available", required: false
    string :notes, description: "Additional accessibility notes", required: false
  end

  object :nearby, description: "Nearby amenities and transportation", required: false do
    string :public_transport, description: "Public transportation options", required: false
    string :parking, description: "Parking information", required: false
  end

  array :locations, description: "Additional event locations", required: false do
    object do
      string :name, description: "Location name"
      string :kind, description: "Type of location (e.g., 'After Party')", required: false
      string :description, description: "Location description", required: false
      string :address, description: "Location address (simple string)", required: false
      string :distance, description: "Distance from main venue", required: false
      string :url, description: "Location website URL", required: false

      object :coordinates, required: false do
        number :latitude
        number :longitude
      end

      object :maps, required: false do
        string :google, description: "Google Maps URL", required: false
        string :apple, description: "Apple Maps URL", required: false
      end
    end
  end

  array :hotels, description: "Recommended hotels near the venue", required: false do
    object do
      string :name, description: "Hotel name"
      string :kind, description: "Type of hotel (e.g., 'Speaker Hotel')", required: false
      string :description, description: "Hotel description", required: false
      string :address, description: "Hotel address", required: false
      string :url, description: "Hotel website URL", required: false
      string :distance, description: "Distance from venue", required: false

      object :coordinates, required: false do
        number :latitude, description: "Latitude coordinate"
        number :longitude, description: "Longitude coordinate"
      end

      object :maps, required: false do
        string :google, description: "Google Maps URL", required: false
        string :apple, description: "Apple Maps URL", required: false
      end
    end
  end
end
