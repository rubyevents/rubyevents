require "test_helper"
require "generators/venue/venue_generator"

class VenueGeneratorTest < Rails::Generators::TestCase
  tests VenueGenerator
  setup do
    self.class.destination Dir.mktmpdir("talk_generator", Rails.root.join("tmp").to_s)
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
    Geocoder::Lookup::Test.add_stub(
      "São Paulo", [
        {
          "coordinates" => [-23.54966, -46.64679],
          "city" => "São Paulo",
          "state" => "SP",
          "country" => "Brazil",
          "country_code" => "BR"
        }
      ]
    )
  end

  teardown do
    FileUtils.remove_entry(destination_root)
    Geocoder::Lookup::Test.reset
  end

  test "minimal venue without geocoder result" do
    venue_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2027/venue.yml")
    assert_nothing_raised do
      run_generator ["--force", # Force file creation
        "--event-series", "tropical-rb",
        "--event", "tropicalrb-2027"]
    end
    # Note: This is intentionally invalid - we want them to supply coordinates
    assert_file venue_file_path do |content|
      assert_match(/street: ""/, content)
      assert_match(/latitude: .NAN # TODO/, content)
      assert_match(/longitude: .NAN # TODO/, content)
    end
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
    assert_valid_file venue_file_path do |content|
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
  end

  test "venue with all optional flags off passes schema validation" do
    venue_file_path = File.join(destination_root, "data/rubyconf/2004/venue.yml")
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

    assert_valid_file venue_file_path do |content|
      assert_match(/name: "Pullman Auditorium"/, content)
    end
  end

  test "venue generator updates existing event's coordinates" do
    event_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2029/event.yml")
    File.join(destination_root, "data/tropical-rb/tropicalrb-2029/venue.yml")

    capture(:stdout) do
      Rails::Generators.invoke "event", [
        "--event-series", "tropical-rb",
        "--event", "tropicalrb-2029",
        "--title", "Tropical on Rails",
        "--start-date", "2029-07-15",
        "--end-date", "2029-07-17",
        "--location", "São Paulo",
        "--latitude", "-23.54966",
        "--longitude", "-46.64679"
      ], behavior: :invoke, destination_root: destination_root
    end

    run_generator ["--force", # Force file creation
      "--event-series", "tropical-rb",
      "--event", "tropicalrb-2029",
      "--name", "Pullman Auditorium"]

    assert_valid_file event_file_path do |content|
      assert_match(/latitude: -23.595/, content)
      assert_match(/longitude: -46.684/, content)
    end
  end

  def assert_valid_file(file_path, msg = nil, &block)
    errors = Static::Validators::Validator.venue_validator_classes.flat_map do |validator|
      validator.new(file_path:).errors
    end
    assert_empty errors, msg || errors.map { |e| e.to_h["message"] }.join(", ")
    assert_file file_path, msg, &block
  end
end
