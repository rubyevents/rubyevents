require "test_helper"
require "generators/venue/venue_generator"

class VenueGeneratorTest < Rails::Generators::TestCase
  tests VenueGenerator
  destination Rails.root.join("tmp/generators/venue")

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

  test "minimal venue without geocoder result" do
    venue_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2027/venue.yml")
    assert_nothing_raised do
      run_generator ["--force", # Force file creation
        "--event-series", "tropical-rb",
        "--event", "tropicalrb-2027"]
    end
    assert_file venue_file_path do |content|
      assert_match(/street: ""/, content)
      assert_match(/latitude: .NAN # TODO/, content)
      assert_match(/longitude: .NAN # TODO/, content)
    end

    File.delete venue_file_path
  end

  test "venue with all flags passes schema validation" do
    run_generator ["--force", # Force file creation
      "--event-series", "tropical-rb",
      "--event", "tropicalrb-2028",
      "--name", "Pullman Auditorium",
      "--address", "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP",
      "--description", "Pullman Auditorium!",
      "--instructions", "Enter through the main doors and check in at the front desk.",
      "--url", "https://example.com/venue",
      "--hotel",
      "--nearby",
      "--locations",
      "--rooms",
      "--spaces",
      "--accessibility"]

    venue_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2028/venue.yml")
    assert_file venue_file_path do |content|
      assert_match(/name: "Pullman Auditorium"/, content)
      assert_match(/description: "Pullman Auditorium!"/, content)
      assert_match(/instructions: "Enter through the main doors and check in at the front desk."/, content)
      assert_match(/url: "https:\/\/example.com\/venue"/, content)
      assert_match(/street: "R. Olimpíadas, 205"/, content)
      assert_match(/city: "São Paulo"/, content)
      assert_match(/region: "SP"/, content)
      assert_match(/postal_code: "04551-000"/, content)
      assert_match(/country: "Brazil"/, content)
      assert_match(/country_code: "BR"/, content)
      assert_match(/latitude: -23.59572/, content)
      assert_match(/longitude: -46.68448/, content)
    end
    validate_venue_schema venue_file_path

    File.delete venue_file_path
  end

  test "venue with all optional flags off passes schema validation" do
    run_generator ["--force", # Force file creation
      "--event-series", "rubyconf",
      "--event", "2004",
      "--name", "Pullman Auditorium",
      "--no-hotel",
      "--no-nearby",
      "--no-locations",
      "--no-rooms",
      "--no-spaces",
      "--no-accessibility"]

    venue_file_path = File.join(destination_root, "data/rubyconf/2004/venue.yml")
    validate_venue_schema venue_file_path

    File.delete venue_file_path
  end

  test "venue generator updates existing event's coordinates" do
    event_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2029/event.yml")
    venue_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2029/venue.yml")

    Rails::Generators.invoke "event", [
      "--event-series", "tropical-rb",
      "--event", "tropicalrb-2029",
      "--title", "Tropical on Rails",
      "--start-date", "2029-07-15",
      "--end-date", "2029-07-17"
    ], behavior: :invoke, destination_root: destination_root

    run_generator ["--force", # Force file creation
      "--event-series", "tropical-rb",
      "--event", "tropicalrb-2029",
      "--name", "Pullman Auditorium"]

    skip "Not yet implemented"
    assert_file event_file_path do |content|
      assert_match(/latitude: -23.59572/, content)
      assert_match(/longitude: -46.68448/, content)
    end
  ensure
    File.delete event_file_path if File.exist?(event_file_path)
    File.delete venue_file_path if File.exist?(venue_file_path)
  end

  def validate_venue_schema(file_path)
    validator = Static::Validators::Schema.new(file_path: file_path)
    assert_empty validator.errors, "Venue YAML does not conform to schema: #{validator.errors.map { |e| e.to_h["message"] }.join(", ")}"
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end
end
