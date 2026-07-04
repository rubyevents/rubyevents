require "test_helper"
require "generators/event/event_generator"
require "fileutils"

class EventGeneratorTest < Rails::Generators::TestCase
  tests EventGenerator
  destination Rails.root.join("tmp/generators/event")

  setup do
    Geocoder::Lookup::Test.set_default_stub([])
    Geocoder::Lookup::Test.add_stub(
      "Pullman Auditorium", [
        {
          "coordinates" => [-23.59572, -46.68448],
          "address" => "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP, 04551-000",
          "city" => "São Paulo",
          "state" => "SP",
          "country" => "Brazil",
          "country_code" => "BR",
          "postal_code" => "04551-000",
          "street_address" => "R. Olimpíadas, 205"
        }
      ]
    )
  end

  test "minimal event passes schema validation" do
    run_generator ["--force", # Force file creation
      "--event-series", "rubyconf",
      "--event", "2028",
      "--title", "RubyConf 2028",
      "--start-date", "2028-11-13",
      "--end-date", "2028-11-15",
      "--online"]

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
    run_generator ["--force", # Force file creation
      "--event-series", "rubyconf",
      "--event", "2027",
      "--title", "RubyConf 2027",
      "--description", "RubyConf 2027 description",
      "--start-date", "2027-11-15",
      "--end-date", "2027-11-17",
      "--date-precision", "year",
      "--announced-on", "2027-01-01",
      "--recordings-published-date", "2027-12-01",
      "--kind", "retreat",
      "--tickets-url", "https://example.com/tickets",
      "--website", "https://example.com/rubyconf-2027",
      "--original-website", "https://example.com/rubyconf-2027-archive",
      "--last-edition",
      "--timezone", "America/Chicago",
      "--online"]

    event_file_path = File.join(destination_root, "data/rubyconf/2027/event.yml")
    validate_event_schema event_file_path

    assert_file event_file_path do |content|
      assert_match(/title: "RubyConf 2027"/, content)
      assert_match(/description: |-\s+RubyConf 2027 description/, content)
      assert_match(/start_date: "2027-11-15"/, content)
      assert_match(/end_date: "2027-11-17"/, content)
      assert_match(/announced_on: "2027-01-01"/, content)
      assert_match(/recordings_published_date: "2027-12-01"/, content)
      assert_match(/year: 2027/, content)
      assert_match(/kind: "retreat"/, content)
      assert_match(/tickets_url: "https:\/\/example.com\/tickets"/, content)
      assert_match(/website: "https:\/\/example.com\/rubyconf-2027"/, content)
      assert_match(/original_website: "https:\/\/example.com\/rubyconf-2027-archive"/, content)
      assert_match(/timezone: "America\/Chicago"/, content)
      assert_match(/last_edition: true/, content)
      assert_match(/location: "online"/, content)
      assert_match(/coordinates: false/, content)
    end

    cleanup_event_directory("2027")
  end

  test "event with location and coordinates" do
    event_file_path = File.join(destination_root, "data/tropical-rb/2028/event.yml")
    run_generator ["--force", # Force file creation
      "--event-series", "tropical-rb",
      "--event", "2028",
      "--title", "Tropical on Rails 2028",
      "--start-date", "2028-07-20",
      "--end-date", "2028-07-22",
      "--location", "Recife, PE, Brazil",
      "--latitude", "-8.04756",
      "--longitude", "-34.877"]
    validate_event_schema event_file_path

    assert_file event_file_path do |content|
      assert_match(/coordinates:\n\s+latitude: -8.04756/, content)
      assert_match(/longitude: -34.877/, content)
    end
  end

  test "event with venue-name and venue-address creates venue.yml" do
    run_generator [
      "--force", # Force file creation
      "--event-series", "rubyconf",
      "--event", "2025",
      "--title", "RubyConf 2025",
      "--start-date", "2025-11-17",
      "--end-date", "2025-11-19",
      "--venue-name", "Pullman Auditorium",
      "--venue-address", "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP, 04551-000"
    ]

    event_file_path = File.join(destination_root, "data/rubyconf/2025/event.yml")
    assert_file event_file_path do |content|
      assert_match(/title: "RubyConf 2025"/, content)
      assert_match(/location: "São Paulo, SP, BR"/, content)
      assert_match(/coordinates:\n\s+latitude: -23.595/, content)
      assert_match(/longitude: -46.684/, content)
    end

    venue_file_path = File.join(destination_root, "data/rubyconf/2025/venue.yml")
    assert_file venue_file_path do |content|
      assert_match(/name: "Pullman Auditorium"/, content)
      assert_match(/street: "R. Olimpíadas, 205"/, content)
      assert_match(/city: "São Paulo"/, content)
      assert_match(/region: "SP"/, content)
      assert_match(/postal_code: "04551-000"/, content)
      assert_match(/country: "Brazil"/, content)
      assert_match(/country_code: "BR"/, content)
      assert_match(/latitude: -23.59572/, content)
      assert_match(/longitude: -46.68448/, content)
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

  teardown do
    Geocoder::Lookup::Test.reset
  end
end
