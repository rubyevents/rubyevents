# frozen_string_literal: true

require "generators/event_base"

class EventGenerator < Generators::EventBase
  source_root File.expand_path("templates", __dir__)
  TOOL_DESC = "Create an event.yml file for an event series, and optionally generate a venue.yml file for the venue."

  class_option :event, type: :string, desc: "Event folder name - a meetup's defaults to its series and date (e.g. lrug-2026-01-12)", required: false, aliases: ["-e"], group: "Fields"
  class_option :title, type: :string, desc: "Event name - a meetup's defaults to its group, Meetup and month, \"<meetup name or series name> Meetup <Month> <Year>\" (without Meetup when the name already says it is a group, like a Ruby Brigade)", group: "Fields"
  class_option :subtitle, type: :string, desc: "What the organizers call the event, next to its title (e.g. \"Pubnite\" or \"Ruby Tuesday #12\" for a meetup)", group: "Fields"
  class_option :description, type: :string, desc: "Event description", group: "Fields"
  class_option :kind, type: :string, enum: Event.kinds.keys, desc: "Event kind (e.g. conference, meetup, workshop)", default: "conference", group: "Fields"

  # Dates
  class_option :date, type: :string, desc: "Date of a one-day event like a meetup (YYYY-MM-DD), sets the start and end date", group: "Fields"
  class_option :start_date, type: :string, desc: "Start date (YYYY-MM-DD)", group: "Fields"
  class_option :end_date, type: :string, desc: "End date (YYYY-MM-DD)", group: "Fields"
  class_option :announced_on, type: :string, desc: "Date when the event was announced (YYYY-MM-DD)", group: "Fields"
  class_option :recordings_published_date, type: :string, desc: "Date when the event's recordings were published (YYYY-MM-DD)", group: "Fields"
  class_option :date_precision, type: :string, enum: ["year", "month", "day"], desc: "Precision of the date (when exact dates are unknown)", group: "Fields"
  class_option :start_time, type: :string, desc: "Start time of a one-day event (HH:MM)", group: "Fields"
  class_option :end_time, type: :string, desc: "End time of a one-day event (HH:MM)", group: "Fields"
  class_option :status, type: :string, enum: ["cancelled", "postponed", "scheduled"], desc: "Event status", group: "Fields"

  # Websites
  class_option :tickets_url, type: :string, desc: "URL to purchase tickets (e.g., Tito, Eventbrite, Luma)", group: "Fields"
  class_option :original_website, type: :string, desc: "Original/archived website URL", group: "Fields"
  class_option :website, type: :string, desc: "Event website URL", group: "Fields"
  class_option :meetup, type: :string, desc: "Meetup.com event URL", group: "Fields"
  class_option :luma, type: :string, desc: "Luma event URL", group: "Fields"
  class_option :kommunity, type: :string, desc: "Kommunity event URL", group: "Fields"

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
  class_option :venue, type: :string, desc: "Name of the venue, without generating a venue.yml (e.g. for a meetup)", group: "Fields"
  # TODO: Save YouTube playlists and videos for another day

  def event_file_path
    @event_file_path ||= File.join(event_directory, "event.yml")
  end

  def validate_options
    raise Thor::RequiredArgumentMissingError, "No value provided for required options '--date' or '--start-date'" if start_date.blank?
    raise Thor::RequiredArgumentMissingError, "No value provided for required options '--end-date'" if end_date.blank?
    raise Thor::RequiredArgumentMissingError, "No value provided for required options '--title'" if title.blank?
    raise Thor::RequiredArgumentMissingError, "No value provided for required options '--event'" if event_folder.blank?
  end

  def initialize_values
    @geocoded_address = nil
    @coordinates = nil

    @location = if options[:online]
      "online"
    elsif meetup? && options[:location].blank? && options[:venue_address].blank? && static_series&.[]("location").present?
      @coordinates = static_series["coordinates"].is_a?(Hash) ? static_series["coordinates"].symbolize_keys : nil
      static_series["location"]
    else
      @geocoded_address = geocode_address(name: options[:venue_name], address: options[:venue_address] || options[:location])
      @coordinates = {
        latitude: options[:latitude] || @geocoded_address&.latitude,
        longitude: options[:longitude] || @geocoded_address&.longitude
      }
      options[:location].presence || [@geocoded_address&.city, @geocoded_address&.state, @geocoded_address&.country_code].compact.join(", ").presence || "Earth"
    end

    @timezone = options[:timezone] || (static_series&.[]("timezone") if meetup?) || "UTC"
  end

  def start_date
    options[:date] || options[:start_date]
  end

  def end_date
    options[:date] || options[:end_date] || (options[:start_date] if meetup?)
  end

  def title
    return options[:title] if options[:title].present?
    return nil unless meetup? && static_series && start_date.present?
    return @title if defined?(@title)

    date = Date.parse(start_date)
    same_month = Static::Validators::MeetupTitle.meetup_dates(series_directory).count { |other| other.year == date.year && other.month == date.month }
    same_month -= 1 if File.exist?(event_file_path)
    month = same_month.positive? ? date.strftime("%B %-d,") : date.strftime("%B")

    @title = "#{Static::Validators::MeetupTitle.title_name(static_series)} #{month} #{date.year}"
  end

  def event_id
    event_folder
  end

  # A meetup's folder is its series and date, with a counter for another meetup on the same day: "lrug-2026-01-12".
  def event_folder
    return options[:event] if options[:event].present?
    return nil unless meetup? && start_date.present?

    base = "#{event_series_slug}-#{start_date}"

    @meetup_folder ||= [base, *(2..9).map { |counter| "#{base}-#{counter}" }].find do |folder|
      !File.exist?(File.join(series_directory, folder, "event.yml"))
    end
  end

  def copy_event_file
    template "event.yml.tt", event_file_path
  end

  def meetup?
    options[:kind] == "meetup"
  end

  def generate_venue_file
    return if options[:online]
    return if options[:venue_name].blank? && options[:venue_address].blank?

    Rails::Generators.invoke "venue", [
      "--event-series", options[:event_series],
      "--event", event_folder,
      "--name", options[:venue_name],
      "--address", options[:venue_address]
    ], behavior: :invoke, destination_root: destination_root
  end
end
