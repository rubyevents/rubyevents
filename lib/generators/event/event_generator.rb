# frozen_string_literal: true

require "generators/event_base"

class EventGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  class_option :name, type: :string, desc: "Event name", group: "Fields", required: true
  class_option :description, type: :string, desc: "Event description", default: "TODO Event description", group: "Fields"
  class_option :kind, type: :string, enum: Event.kinds.keys, desc: "Event kind (e.g. conference, meetup, workshop)", default: "conference", group: "Fields"
  class_option :start_date, type: :string, desc: "Start date (YYYY-MM-DD)", default: "2026-01-01", group: "Fields"
  class_option :end_date, type: :string, desc: "End date (YYYY-MM-DD)", default: "2026-12-31", group: "Fields"
  class_option :tickets_url, type: :string, desc: "URL to purchase tickets (e.g., Tito, Eventbrite, Luma)", default: "TODO: https://www.todo.example.com/tickets", group: "Fields"
  class_option :website, type: :string, desc: "Event website URL", default: "TODO: https://www.todo.example.com", group: "Fields"
  class_option :last_edition, type: :boolean, desc: "Is this the last edition?", default: false, group: "Fields"
  # Location Details
  class_option :online, type: :boolean, desc: "Is this an online-only event?", default: false, group: "Fields"
  class_option :location, type: :string, desc: "Location (City, Country)", group: "Fields"
  class_option :venue_name, type: :string, desc: "TODO Venue name", default: "TODO", group: "Fields"
  class_option :venue_address, type: :string, desc: "Venue address", default: "123 TODO St, City, State, ZIP, Country", group: "Fields"
  # TODO: Save YouTube playlists and videos for another day
  # TODO: Save "with-series" option for another day

  def initialize_values
    @year = Date.parse(options[:start_date]).year
    @geocoded_address = geocode_address(name: options[:venue_name], address: options[:venue_address] || options[:location])
    @location = if options[:online]
      "online"
    else
      options[:location].presence || [@geocoded_address.city, @geocoded_address.state, @geocoded_address.country_code].compact.join(", ").presence || "Earth"
    end
  end

  def copy_event_file
    template "event.yml.tt", File.join(["data", options[:event_series], options[:event], "event.yml"])
  end

  def generate_venue_file
    return if options[:online]
    return if options[:venue_name].blank? && options[:venue_address].blank?
    return if options[:venue_name] == "TODO Venue name" && options[:venue_address] == "123 TODO St, City, State, ZIP, Country"

    Rails::Generators.invoke "venue", [
      "--event-series", options[:event_series],
      "--event", options[:event],
      "--name", options[:venue_name],
      "--address", options[:venue_address]
    ], behavior: :invoke, destination_root: destination_root
  end
end
