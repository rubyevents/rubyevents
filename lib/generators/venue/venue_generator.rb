# frozen_string_literal: true

require "generators/event_base"

class VenueGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

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
end
