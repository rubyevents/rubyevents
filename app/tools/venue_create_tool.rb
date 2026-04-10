# frozen_string_literal: true

class VenueCreateTool < RubyLLM::Tool
  description "Create a venue.yml file for an event by geocoding a venue name/address. Creates the file with coordinates and map links."

  param :event_query, desc: "Event slug or name to find (e.g., 'tropical-on-rails-2026' or 'Tropical on Rails 2026')"
  param :venue_name, desc: "Name of the venue (e.g., 'Convention Center City', 'Hotel Ambasciatori')"
  param :address, desc: "Full address or location (e.g., 'Viale Vespucci 22, 47921 Rimini, Italy')", required: false
  param :source_url, desc: "URL where the venue information was found", required: false

  def execute(event_query:, venue_name:, address: nil, source_url: nil)
    event = find_event(event_query)
    return {error: "Event not found for query: #{event_query}"} if event.nil?

    if event.venue.exist?
      return {
        warning: "Venue file already exists",
        event: event.name,
        venue_file: event.venue.file_path.to_s.sub(Rails.root.to_s + "/", ""),
        existing_venue: event.venue.name
      }
    end

    search_string = [venue_name, address].compact.join(", ")
    geocode_results = Geocoder.search(search_string)

    if geocode_results.empty?
      return {error: "Could not geocode address: #{search_string}"}
    end

    geo = geocode_results.first

    venue_data = {
      "name" => venue_name,
      "address" => {
        "street" => geo.street_address,
        "city" => geo.city,
        "region" => geo.state,
        "postal_code" => geo.postal_code,
        "country" => geo.country,
        "country_code" => geo.country_code,
        "display" => geo.formatted_address
      }.compact,
      "coordinates" => {
        "latitude" => geo.latitude,
        "longitude" => geo.longitude
      },
      "maps" => {
        "google" => "https://maps.google.com/?q=#{venue_name.tr(" ", "+")},#{geo.latitude},#{geo.longitude}",
        "apple" => "https://maps.apple.com/?q=#{venue_name.tr(" ", "+")}&ll=#{geo.latitude},#{geo.longitude}",
        "openstreetmap" => "https://www.openstreetmap.org/?mlat=#{geo.latitude}&mlon=#{geo.longitude}"
      }
    }

    source = "# #{source_url}\n\n" if source_url.present?

    file_content = <<~YAML
      #{source}
      #{venue_data.to_yaml}
    YAML

    File.write(event.venue.file_path, file_content)

    {
      success: true,
      event: event.name,
      venue_file: event.venue.file_path.to_s.sub(Rails.root.to_s + "/", ""),
      venue: venue_data
    }
  rescue => e
    {error: e.message, backtrace: e.backtrace.first(5)}
  end

  private

  def find_event(query)
    Event.find_by(slug: query) ||
      Event.find_by(slug: query.parameterize) ||
      Event.find_by(name: query) ||
      Event.ft_search(query).first
  end
end
