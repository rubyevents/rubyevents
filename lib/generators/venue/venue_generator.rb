# frozen_string_literal: true

require "generators/event_base"

class VenueGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)

  class_option :name, type: :string, desc: "Venue name", default: "TODO Venue name", group: "Fields"
  class_option :address, type: :string, desc: "Venue address", default: "123 TODO St, City, State, ZIP, Country", group: "Fields"
  class_option :accessibility, type: :boolean, desc: "Include accessibility information section", default: true, group: "Fields"
  class_option :description, type: :string, desc: "Description of venue", default: "TODO - Description of the venue - Optional"
  class_option :url, type: :string, desc: "Hotel website", default: "https://TODO.example.com"

  # Add Section
  class_option :hotels, type: :boolean, desc: "Include hotel information section", default: false, group: "Fields"
  class_option :nearby, type: :boolean, desc: "Include nearby amenities section", default: false, group: "Fields"
  class_option :locations, type: :boolean, desc: "Include additional locations section", default: false, group: "Fields"
  class_option :rooms, type: :boolean, desc: "Include rooms section", default: false, group: "Fields"
  class_option :spaces, type: :boolean, desc: "Include spaces section", default: false, group: "Fields"

  def copy_venue_file
    venue_file = File.join([event_directory, "venue.yml"])
    @geocoded_address = geocode_address(name: options[:name], address: options[:address])

    if File.exist?(venue_file)
      append_to_file(venue_file, template_content("location.yml.tt"))
    else
      template "venue.yml.tt", venue_file
    end
  end
end
