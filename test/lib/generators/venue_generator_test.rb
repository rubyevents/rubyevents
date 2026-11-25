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
    Geocoder::Lookup::Test.add_stub(
      "Party Hall", [
        {
          "coordinates" => [60.194226, 24.945257],
          "address" => "Traverssikuja 3, 00510 Helsinki, Finland",
          "city" => "Helsinki",
          "state" => "Uusimaa",
          "country" => "Finland",
          "country_code" => "FI",
          "postal_code" => "00510",
          "street_address" => "Traverssikuja 3"
        }
      ]
    )
    Geocoder::Lookup::Test.add_stub(
      "Gala Hall", [
        {
          "coordinates" => [52.52, 13.405],
          "address" => "1 Main St, 10115 Berlin, Germany",
          "city" => "Berlin",
          "state" => "Berlin",
          "country" => "Germany",
          "country_code" => "DE",
          "postal_code" => "10115",
          "street_address" => "1 Main St"
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
      "--nearby",
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
      "--no-nearby",
      "--no-rooms",
      "--no-spaces",
      "--no-accessibility"]

    assert_valid_file venue_file_path do |content|
      assert_match(/name: "Pullman Auditorium"/, content)
    end
  end

  test "adds multiple additional locations without touching the primary venue" do
    venue_file_path = File.join(destination_root, "data/tiny-ruby-conf/tiny-ruby-conf-2026/venue.yml")
    run_generator ["--force",
      "--event-series", "tiny-ruby-conf",
      "--event", "tiny-ruby-conf-2026",
      "--name", "Pullman Auditorium",
      "--address", "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP"]

    run_generator ["--event-series", "tiny-ruby-conf",
      "--event", "tiny-ruby-conf-2026",
      "--additional_location", "Afterparty Location",
      "--name", "Party Hall",
      "--address", "Traverssikuja 3, 00510 Helsinki, Finland",
      "--description", "Official afterparty",
      "--url", "https://example.com/party"]

    run_generator ["--event-series", "tiny-ruby-conf",
      "--event", "tiny-ruby-conf-2026",
      "--additional_location", "Hotel",
      "--name", "Gala Hall",
      "--address", "1 Main St, 10115 Berlin, Germany"]

    assert_valid_file venue_file_path do |content|
      assert_match(/name: "?Pullman Auditorium/, content)
      assert_equal 2, content.scan(/^  - name:/).length
      assert_match(/- name: "?Party Hall/, content)
      assert_match(/kind: "?Afterparty Location/, content)
      assert_match(/description: "?Official afterparty/, content)
      assert_match(/street: "?Traverssikuja 3/, content)
      assert_match(/postal_code: "?00510/, content)
      assert_match(/latitude: 60.194226/, content)
      assert_match(/longitude: 24.945257/, content)
      assert_match(%r{url: "?https://example.com/party}, content)
      assert_match(/- name: "?Gala Hall/, content)
      assert_match(/kind: "?Hotel/, content)
      assert_match(/city: "?Berlin/, content)
    end
  end

  test "adds a hotel location to a venue that has no locations section" do
    venue_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2030/venue.yml")
    run_generator ["--force",
      "--event-series", "tropical-rb",
      "--event", "tropicalrb-2030",
      "--name", "Pullman Auditorium",
      "--address", "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP"]

    run_generator ["--event-series", "tropical-rb",
      "--event", "tropicalrb-2030",
      "--additional_location", "conference hotel",
      "--name", "Party Hall",
      "--address", "Traverssikuja 3, 00510 Helsinki, Finland"]

    assert_valid_file venue_file_path do |content|
      assert_match(/^locations:/, content)
      assert_match(/- name: "?Party Hall/, content)
      assert_match(/kind: "?Conference Hotel/, content)
      assert_match(/city: "?Helsinki/, content)
    end
  end

  test "adding an additional location requires an existing venue file" do
    output = capture(:stderr) do
      run_generator ["--event-series", "tropical-rb",
        "--event", "tropicalrb-2031",
        "--additional_location", "Hotel",
        "--name", "Party Hall",
        "--address", "Traverssikuja 3, 00510 Helsinki, Finland"]
    end

    assert_match(/No venue.yml found/, output)
  end

  test "adding an additional location leaves the event coordinates unchanged" do
    event_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2032/event.yml")
    venue_file_path = File.join(destination_root, "data/tropical-rb/tropicalrb-2032/venue.yml")

    capture(:stdout) do
      Rails::Generators.invoke "event", [
        "--event-series", "tropical-rb",
        "--event", "tropicalrb-2032",
        "--title", "Tropical on Rails",
        "--start-date", "2032-07-15",
        "--end-date", "2032-07-17",
        "--location", "São Paulo",
        "--latitude", "-23.54966",
        "--longitude", "-46.64679"
      ], behavior: :invoke, destination_root: destination_root
    end

    run_generator ["--force",
      "--event-series", "tropical-rb",
      "--event", "tropicalrb-2032",
      "--name", "Pullman Auditorium",
      "--address", "R. Olimpíadas, 205 - Vila Olímpia, São Paulo - SP"]

    run_generator ["--event-series", "tropical-rb",
      "--event", "tropicalrb-2032",
      "--additional_location", "Hotel",
      "--name", "Party Hall",
      "--address", "Traverssikuja 3, 00510 Helsinki, Finland"]

    assert_file event_file_path do |content|
      assert_match(/latitude: -23.5957/, content)
      assert_match(/longitude: -46.6845/, content)
    end
  ensure
    File.delete(event_file_path) if File.exist?(event_file_path)
    File.delete(venue_file_path) if File.exist?(venue_file_path)
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
