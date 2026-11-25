# frozen_string_literal: true

require "generators/event_base"

class VenueGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Create a venue.yml file for a given event and update the event.yml file with the venue's coordinates, or add an additional location to an existing venue.yml with --additional_location."

  class_option :name, type: :string, desc: "Venue name", group: "Fields"
  class_option :address, type: :string, desc: "Venue address", group: "Fields"
  class_option :description, type: :string, desc: "Description of venue", group: "Fields"
  class_option :instructions, type: :string, desc: "Instructions for getting to the venue", group: "Fields"
  class_option :url, type: :string, desc: "Venue or additional location website", group: "Fields"

  # Add Section
  class_option :accessibility, type: :boolean, desc: "Include accessibility information section", default: false, group: "Fields"
  class_option :nearby, type: :boolean, desc: "Include nearby amenities section", default: false, group: "Fields"
  class_option :rooms, type: :boolean, desc: "Include rooms section", default: false, group: "Fields"
  class_option :spaces, type: :boolean, desc: "Include spaces section", default: false, group: "Fields"

  # Add an additional location (e.g. a hotel or afterparty) to an existing venue.yml.
  # Its value is the location's kind, and the other fields are reused from the
  # regular flags above.
  class_option :additional_location, type: :string, desc: "Add an additional location of this kind to an existing venue.yml (e.g. 'Hotel' or 'Afterparty Location'). Reuses --name, --address, --description and --url.", group: "Fields"

  def apple_maps
    return unless geocoded_address
    "https://maps.apple.com/?q=#{options[:name]&.tr(" ", "+")}&ll=#{geocoded_address.latitude},#{geocoded_address.longitude}"
  end

  def geocoded_address
    @geocoded_address ||= geocode_address(name: options[:name], address: options[:address])
  end

  def google_maps
    return unless geocoded_address
    "https://maps.google.com/?q=#{options[:name]&.tr(" ", "+")},#{geocoded_address.latitude},#{geocoded_address.longitude}"
  end

  def openstreetmap_maps
    return unless geocoded_address
    "https://www.openstreetmap.org/?mlat=#{geocoded_address.latitude}&mlon=#{geocoded_address.longitude}"
  end

  def copy_venue_file
    return if additional_location?

    venue_file = File.join([event_directory, "venue.yml"])
    template "venue.yml.tt", venue_file
  end

  def add_additional_location
    return unless additional_location?

    venue_file = File.join([event_directory, "venue.yml"])
    raise Thor::Error, "No venue.yml found at #{venue_file}. Generate the venue first." unless File.exist?(venue_file)
    raise Thor::Error, "--name is required with --additional_location." if options[:name].blank?

    location = location_details
    document = Yerba.parse_file(venue_file)

    if document["locations"]
      document["locations"] << location
    else
      document["locations"] = [location]
    end
    document.save!(apply: true)

    say("Added #{location["name"]} (#{location["kind"]}) to #{venue_file}.", :green)
  end

  def update_event_file
    return if additional_location?
    return unless @geocoded_address
    event_file = File.join([event_directory, "event.yml"])
    return unless File.exist?(event_file)
    @coordinates = {latitude: geocoded_address.latitude, longitude: geocoded_address.longitude}

    event = Static::Event.in_file(event_file).first
    event["coordinates.latitude"] = @coordinates[:latitude]
    event["coordinates.longitude"] = @coordinates[:longitude]
    event.save!
  end

  private

  def additional_location?
    options[:additional_location].present?
  end

  def location_details
    address = location_address
    maps = location_maps

    location = {
      "name" => options[:name].to_s,
      "kind" => location_kind
    }
    location["description"] = options[:description] if options[:description].present?
    location["address"] = address if address
    location["url"] = options[:url] if options[:url].present?
    location["coordinates"] = {
      "latitude" => geocoded_address&.latitude || 0.0,
      "longitude" => geocoded_address&.longitude || 0.0
    }
    location["maps"] = maps if maps
    location
  end

  # Hotels are identified by a case-sensitive /Hotel/ match in Event::Venue, so
  # normalize kinds like "hotel" or "conference hotel" before writing them.
  def location_kind
    kind = options[:additional_location].to_s.strip.gsub(/hotel/i, "Hotel")
    kind.sub(/\A[a-z]/, &:upcase)
  end

  def location_address
    return unless geocoded_address

    address = {
      "street" => geocoded_address.street_address.to_s,
      "city" => geocoded_address.city.to_s
    }
    address["region"] = geocoded_address.state if geocoded_address.state.present?
    address["postal_code"] = geocoded_address.postal_code if geocoded_address.postal_code.present?
    address["country"] = geocoded_address.country.to_s
    address["country_code"] = geocoded_address.country_code.to_s
    address["display"] = options[:address].presence || geocoded_address.address.to_s
    address
  end

  def location_maps
    return unless geocoded_address

    {"google" => google_maps, "apple" => apple_maps, "openstreetmap" => openstreetmap_maps}
  end
end
