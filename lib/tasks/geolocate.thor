require "bundler/setup"
require "dotenv/load"
require "parallel"
require_relative "../../config/environment"

class Geolocate < Thor
  desc "files [FILES...]", "Geolocate event.yml files based on location field"
  option :overwrite, type: :boolean, default: false, desc: "Overwrite existing coordinates"
  def files(*file_patterns)
    file_patterns = ["data/**/event.yml"] if file_patterns.empty?

    files = file_patterns.flat_map { |pattern| Dir.glob(pattern) }.uniq
    if files.empty?
      puts "No files found matching patterns: #{file_patterns.join(", ")}"
      exit 1
    end

    Parallel.each(files, in_threads: 5) do |file_path|
      process_event_file(file_path, options[:overwrite])
    end
  end

  desc "events", "Geolocate events from the database based on location field"
  option :overwrite, type: :boolean, default: false, desc: "Overwrite existing coordinates"
  def events
    events_to_geocode = if options[:overwrite]
      Event.all
    else
      Event.where(longitude: nil).or(Event.where(latitude: nil))
    end

    if events_to_geocode.empty?
      puts "No events to geocode"
      return
    end

    Parallel.each(events_to_geocode, in_threads: 5) do |event|
      process_event(event, options[:overwrite])
    end
  end

  private

  def process_event_file(file_path, overwrite)
    event = Static::Event.in_file(file_path).first

    if event.to_h.empty?
      puts "⚠ Skipping #{file_path}, invalid YAML structure"
      return
    end

    # Prioritize venue.yml if it exists and has coordinates
    venue = event.venue
    if venue
      venue_coordinates = venue["coordinates"]
      if venue_coordinates && venue_coordinates["latitude"] && venue_coordinates["longitude"]
        if event["coordinates"] != venue_coordinates || overwrite
          event["coordinates"] = venue_coordinates
          event.save!
          puts "✓ #{file_path}: Updated from venue.yml -> #{venue_coordinates}"
        else
          puts "⚠ Skipping #{file_path}: Already has coordinates from venue"
        end
        return
      end
    end

    location = event["location"]
    unless location.present?
      puts "⚠ Skipping #{file_path}: No location field"
      return
    end

    if event["coordinates"] && !overwrite
      puts "⚠ Skipping #{file_path}: Already has coordinates"
      return
    end

    coordinates = geocode_location(location)

    if coordinates
      event["coordinates"] = coordinates
      event.save!
      puts "✓ #{file_path}: #{event["title"]} (#{location}) -> #{coordinates}"
    else
      puts "✗ #{file_path}: Failed to geocode (#{location})"
    end
  rescue => e
    puts "✗ Error processing #{file_path}: #{e.message}"
  end

  def process_event(event, overwrite)
    coordinates = event.venue.exist? ? event.venue.coordinates : event.static_metadata&.coordinates
    unless coordinates.present?
      puts "⚠ Skipping #{event.name}: No coordinates in venue or metadata"
      return
    end

    if event.longitude.present? && event.latitude.present? && !overwrite
      puts "⚠ Skipping #{event.name}: Already has coordinates"
      return
    end

    if coordinates
      lat = coordinates["latitude"]
      lng = coordinates["longitude"]
      event.update(longitude: lng, latitude: lat)
      puts "✓ #{event.name} -> #{lat}, #{lng}"
    else
      puts "✗ Failed to geocode #{event.name}"
    end
  rescue => e
    puts "✗ Error processing #{event.name}: #{e.message}"
  end

  def geocode_location(location)
    result = Geocoder.search(location).first
    return nil unless result

    {"latitude" => result.latitude, "longitude" => result.longitude}
  rescue => e
    puts "    Error: #{e.message}"
    nil
  end
end
