# frozen_string_literal: true

class VenueSchema < RubyLLM::Schema
  string :name, description: "Name of the venue"
  string :description, description: "Description of the venue", required: false
  string :instructions, description: "Instructions for getting to the venue", required: false
  string :url, description: "Venue website URL", required: false

  object :address, of: AddressSchema, description: "Physical address of the venue"
  object :coordinates, of: CoordinatesSchema, description: "Geographic coordinates"
  object :maps, of: MapsSchema, description: "Links to various map services", required: false

  array :locations, of: LocationSchema, description: "Additional event locations", required: false
  array :hotels, of: HotelSchema, description: "Recommended hotels near the venue", required: false

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
end
