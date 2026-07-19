# frozen_string_literal: true

require "generators/event_base"

class VenueGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Create a venue.yml file for a given event and update the event.yml file with the venue's coordinates."

  class_option :name, type: :string, desc: "Venue name", group: "Fields"
  class_option :address, type: :string, desc: "Venue address", group: "Fields"
  class_option :description, type: :string, desc: "Description of venue", group: "Fields"
  class_option :instructions, type: :string, desc: "Instructions for getting to the venue", group: "Fields"
  class_option :url, type: :string, desc: "Hotel website", group: "Fields"

  # Add Section
  class_option :accessibility, type: :boolean, desc: "Include accessibility information section", default: false, group: "Fields"
  class_option :hotels, type: :boolean, desc: "Include hotel information section", default: false, group: "Fields"
  class_option :locations, type: :boolean, desc: "Include additional locations section", default: false, group: "Fields"
  class_option :nearby, type: :boolean, desc: "Include nearby amenities section", default: false, group: "Fields"
  class_option :rooms, type: :boolean, desc: "Include rooms section", default: false, group: "Fields"
  class_option :spaces, type: :boolean, desc: "Include spaces section", default: false, group: "Fields"

  def copy_venue_file
    venue_file = File.join([event_directory, "venue.yml"])
    @geocoded_address = geocode_address(name: options[:name], address: options[:address])

    template "venue.yml.tt", venue_file
  end

  def update_event_file
    return unless @geocoded_address
    event_file = File.join([event_directory, "event.yml"])
    return unless File.exist?(event_file)
    @coordinates = {latitude: @geocoded_address.latitude, longitude: @geocoded_address.longitude}

    event_document = Yerba.parse_file(event_file)
    event_document["coordinates.latitude"] = @coordinates[:latitude]
    event_document["coordinates.longitude"] = @coordinates[:longitude]
    event_document.save!
  end
end
