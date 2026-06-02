require "test_helper"
require "generators/event/event_generator"
require "fileutils"

class EventGeneratorTest < Rails::Generators::TestCase
  tests EventGenerator
  destination Rails.root.join("tmp/generators/event")

  test "minimal event passes schema validation" do
    run_generator [
      "--force", # Force file creation
      "--event-series", "rubyconf",
      "--event", "2028",
      "--title", "RubyConf 2028",
      "--start-date", "2028-11-13",
      "--end-date", "2028-11-15",
      "--online"
    ]

    event_file_path = File.join(destination_root, "data/rubyconf/2028/event.yml")
    validate_event_schema event_file_path

    assert_file event_file_path do |content|
      assert_match(/title: "RubyConf 2028"/, content)
      assert_match(/start_date: "2028-11-13"/, content)
      assert_match(/end_date: "2028-11-15"/, content)
      assert_match(/year: 2028/, content)
      assert_match(/location: "online"/, content)
      assert_match(/coordinates: false/, content)
    end

    cleanup_event_directory("2028")
  end

  test "event with all flags passes schema validation" do
    run_generator [
      "--force", # Force file creation
      "--event-series", "rubyconf",
      "--event", "2027",
      "--title", "RubyConf 2027",
      "--description", "RubyConf 2027 description",
      "--start-date", "2027-11-15",
      "--end-date", "2027-11-17",
      "--kind", "retreat",
      "--tickets-url", "https://example.com/tickets",
      "--website", "https://example.com/rubyconf-2027",
      "--last-edition",
      "--timezone", "America/Chicago",
      "--online"
    ]

    event_file_path = File.join(destination_root, "data/rubyconf/2027/event.yml")
    validate_event_schema event_file_path

    assert_file event_file_path do |content|
      assert_match(/title: "RubyConf 2027"/, content)
      assert_match(/description: |-\s+RubyConf 2027 description/, content)
      assert_match(/start_date: "2027-11-15"/, content)
      assert_match(/end_date: "2027-11-17"/, content)
      assert_match(/year: 2027/, content)
      assert_match(/kind: "retreat"/, content)
      assert_match(/tickets_url: "https:\/\/example.com\/tickets"/, content)
      assert_match(/website: "https:\/\/example.com\/rubyconf-2027"/, content)
      assert_match(/timezone: "America\/Chicago"/, content)
      assert_match(/last_edition: true/, content)
      assert_match(/location: "online"/, content)
      assert_match(/coordinates: false/, content)
    end

    cleanup_event_directory("2027")
  end

  test "event with venue-name and venue-address creates venue.yml" do
    geocoded_address = Generators::EventBase::GeocodedAddress.new(
      street_address: "123 Main St",
      city: "Test City",
      state: "TS",
      postal_code: "12345",
      country: "Testland",
      country_code: "TL",
      latitude: 1.23,
      longitude: 4.56
    )

    with_stubbed_geocoder_result(geocoded_address) do
      run_generator [
        "--force", # Force file creation
        "--event-series", "rubyconf",
        "--event", "2025",
        "--title", "RubyConf 2025",
        "--start-date", "2025-11-17",
        "--end-date", "2025-11-19",
        "--venue-name", "RubyConf 2025 Venue",
        "--venue-address", "123 Main St, Test City"
      ]
    end

    event_file_path = File.join(destination_root, "data/rubyconf/2025/event.yml")
    assert_file event_file_path do |content|
      assert_match(/title: "RubyConf 2025"/, content)
      assert_match(/location: "Test City, TS, TL"/, content)
      assert_match(/coordinates:\n\s+latitude: 1.23/, content)
      assert_match(/longitude: 4.56/, content)
    end

    venue_file_path = File.join(destination_root, "data/rubyconf/2025/venue.yml")
    assert_file venue_file_path do |content|
      assert_match(/RubyConf 2025 Venue/, content)
      assert_match(/123 Main St/, content)
    end

    validate_event_schema event_file_path
    cleanup_event_directory("2025")
  end

  def validate_event_schema(file_path)
    schema_validator = Static::Validators::Schema.new(file_path: file_path)
    assert_empty schema_validator.errors, "Event YAML does not conform to schema: #{schema_validator.errors.map { |e| e.to_h["message"] }.join(", ")}"
    dates_validator = Static::Validators::EventDates.new(file_path: file_path)
    assert_empty dates_validator.errors, "Event YAML is missing required start_date or end_date: #{dates_validator.errors.map { |e| e.to_h["message"] }.join(", ")}"
  end

  def cleanup_event_directory(event_slug)
    FileUtils.rm_rf(File.join(destination_root, "data/rubyconf", event_slug))
  end

  def with_stubbed_geocoder_result(result)
    geocoder_singleton = Geocoder.singleton_class
    original_search = Geocoder.method(:search)

    geocoder_singleton.send(:define_method, :search) do |*|
      [result]
    end

    yield
  ensure
    geocoder_singleton.send(:define_method, :search, original_search)
  end
end
