# frozen_string_literal: true

namespace :cities do
  desc "Create cities from all event and user locations"
  task create: :environment do
    puts "Creating cities from events and users..."

    created_count = 0
    skipped_count = 0

    event_locations = Event
      .where.not(city: [nil, ""])
      .where.not(country_code: [nil, ""])
      .distinct
      .pluck(:city, :country_code, :state_code, :latitude, :longitude)

    puts "Found #{event_locations.size} unique event locations"

    event_locations.each do |city, country_code, state_code, latitude, longitude|
      result = City.find_or_create_for(
        city: city,
        country_code: country_code,
        state_code: state_code,
        latitude: latitude,
        longitude: longitude
      )

      if result&.previously_new_record?
        created_count += 1
        puts "  Created: #{city}, #{state_code}, #{country_code}"
      else
        skipped_count += 1
      end
    end

    user_locations = User
      .where.not(city: [nil, ""])
      .where.not(country_code: [nil, ""])
      .distinct
      .pluck(:city, :country_code, :state_code, :latitude, :longitude)

    puts "Found #{user_locations.size} unique user locations"

    user_locations.each do |city, country_code, state_code, latitude, longitude|
      result = City.find_or_create_for(
        city: city,
        country_code: country_code,
        state_code: state_code,
        latitude: latitude,
        longitude: longitude
      )

      if result&.previously_new_record?
        created_count += 1
        puts "  Created: #{city}, #{state_code}, #{country_code}"
      else
        skipped_count += 1
      end
    end

    puts ""
    puts "Done! Created #{created_count} cities, skipped #{skipped_count} existing"
    puts "Total cities in database: #{City.count}"
  end

  desc "Geocode cities that are missing coordinates"
  task geocode: :environment do
    cities = City.where(latitude: nil).or(City.where(longitude: nil))
    total = cities.count

    puts "Geocoding #{total} cities without coordinates..."

    cities.find_each.with_index do |city, index|
      print "\r  Processing #{index + 1}/#{total}: #{city.name}, #{city.country_code}..."

      begin
        city.geocode
        if city.geocoded?
          city.save!
          print " ✓"
        else
          print " (no results)"
        end
      rescue => e
        print " ERROR: #{e.message}"
      end

      sleep 0.1
    end

    puts ""
    puts "Done!"
  end

  desc "Remove cities that are actually countries, states, or regions"
  task cleanup: :environment do
    puts "Finding invalid city names..."

    invalid_cities = City.all.select do |city|
      city.valid?
      city.errors[:name].any?
    end

    if invalid_cities.empty?
      puts "No invalid cities found."
    else
      puts "Found #{invalid_cities.size} invalid cities:"

      invalid_cities.each do |city|
        city.valid?
        reasons = city.errors[:name].join(", ")
        location = [city.name, city.state_code, city.country_code].compact.join(", ")
        types = city.geocode_metadata&.dig("types")&.join(", ") || "unknown"

        puts "  - #{location} (geocoded as: #{types}): #{reasons}"
      end

      print "\nDelete these cities? [y/N] "

      if ENV["FORCE"] == "true" || $stdin.gets&.strip&.downcase == "y"
        invalid_cities.each(&:destroy)
        puts "Deleted #{invalid_cities.size} invalid cities."
      else
        puts "Aborted."
      end
    end
  end

  desc "List cities with event and user counts"
  task stats: :environment do
    puts "City Statistics"
    puts "=" * 60

    cities = City.all.map do |city|
      {
        name: city.name,
        state: city.state_code,
        country: city.country_code,
        events: city.events_count,
        users: city.users_count,
        geocoded: city.geocoded?
      }
    end

    cities.sort_by! { |c| -(c[:events] + c[:users]) }

    cities.each do |city|
      location = [city[:name], city[:state], city[:country]].compact.join(", ")
      geo = city[:geocoded] ? "✓" : "✗"
      puts "#{geo} #{location.ljust(40)} Events: #{city[:events].to_s.rjust(3)} | Users: #{city[:users].to_s.rjust(3)}"
    end

    puts ""
    puts "Total: #{City.count} cities"
    puts "Geocoded: #{City.where.not(latitude: nil).count}"
    puts "Not geocoded: #{City.where(latitude: nil).count}"
  end
end
