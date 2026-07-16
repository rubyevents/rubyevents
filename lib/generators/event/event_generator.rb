# frozen_string_literal: true

require "generators/event_base"

class EventGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  class_option :title, type: :string, desc: "Event name", group: "Fields", required: true
  class_option :description, type: :string, desc: "Event description", group: "Fields"
  class_option :kind, type: :string, enum: Event.kinds.keys, desc: "Event kind (e.g. conference, meetup, workshop)", default: "conference", group: "Fields"

  # Dates
  class_option :start_date, type: :string, desc: "Start date (YYYY-MM-DD)", required: true, group: "Fields"
  class_option :end_date, type: :string, desc: "End date (YYYY-MM-DD)", required: true, group: "Fields"
  class_option :announced_on, type: :string, desc: "Date when the event was announced (YYYY-MM-DD)", group: "Fields"
  class_option :recordings_published_date, type: :string, desc: "Date when the event's recordings were published (YYYY-MM-DD)", group: "Fields"
  class_option :date_precision, type: :string, enum: ["year", "month", "day"], desc: "Precision of the date (when exact dates are unknown)", group: "Fields"

  # Websites
  class_option :tickets_url, type: :string, desc: "URL to purchase tickets (e.g., Tito, Eventbrite, Luma)", group: "Fields"
  class_option :original_website, type: :string, desc: "Original/archived website URL", group: "Fields"
  class_option :website, type: :string, desc: "Event website URL", group: "Fields"

  # Flags
  class_option :last_edition, type: :boolean, desc: "Is this the last edition?", default: false, group: "Fields"

  # Location Details
  class_option :online, type: :boolean, desc: "Is this an online-only event?", default: false, group: "Fields"
  class_option :location, type: :string, desc: "Location (City, Country)", group: "Fields"
  class_option :latitude, type: :string, desc: "Latitude", group: "Fields"
  class_option :longitude, type: :string, desc: "Longitude", group: "Fields"
  class_option :timezone, type: :string, desc: "IANA timezone identifier (e.g. America/New_York)", group: "Fields"
  class_option :venue_name, type: :string, desc: "Venue name - will generate venue.yml", group: "Fields"
  class_option :venue_address, type: :string, desc: "Venue address - will generate venue.yml", group: "Fields"
  # TODO: Save YouTube playlists and videos for another day
  # TODO: Save "with-series" option for another day

  def event_file_path
    @event_file_path ||= File.join(event_directory, "event.yml")
  end

  def initialize_values
    @year = Date.parse(options[:start_date]).year
    @geocoded_address = nil
    @location = if options[:online]
      "online"
    else
      @geocoded_address = geocode_address(name: options[:venue_name], address: options[:venue_address] || options[:location])
      @coordinates = {
        latitude: options[:latitude] || @geocoded_address&.latitude,
        longitude: options[:longitude] || @geocoded_address&.longitude
      }
      options[:location].presence || [@geocoded_address&.city, @geocoded_address&.state, @geocoded_address&.country_code].compact.join(", ").presence || "Earth"
    end
    @timezone = options[:timezone] || "UTC"
  end

  def copy_event_file
    template "event.yml.tt", event_file_path
  end

  def generate_venue_file
    return if options[:online]
    return if options[:venue_name].blank? && options[:venue_address].blank?

    Rails::Generators.invoke "venue", [
      "--event-series", options[:event_series],
      "--event", options[:event],
      "--name", options[:venue_name],
      "--address", options[:venue_address]
    ], behavior: :invoke, destination_root: destination_root
  end
end
