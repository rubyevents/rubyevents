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
    event_file_path = File.join(destination_root, "data/rubyconf/2021/event.yml")
    eliminate_validated_file(file_path: event_file_path) do
      run_generator ["--force", # Force file creation
        "--event-series", "rubyconf",
        "--event", "2021",
        "--title", "RubyConf 2021",
        "--start-date", "2021-11-13",
        "--end-date", "2021-11-15",
        "--online"]

      assert_file event_file_path do |content|
        assert_match(/title: "RubyConf 2021"/, content)
        assert_match(/start_date: "2021-11-13"/, content)
        assert_match(/end_date: "2021-11-15"/, content)
        assert_match(/year: 2021/, content)
        assert_match(/location: "online"/, content)
        assert_match(/coordinates: false/, content)
      end
    end
  end

  test "event with all flags passes schema validation" do
    event_file_path = File.join(destination_root, "data/rubyconf/2022/event.yml")
    eliminate_validated_file(file_path: event_file_path) do
      run_generator ["--force", # Force file creation
        "--event-series", "rubyconf",
        "--event", "2022",
        "--title", "RubyConf 2022",
        "--description", "RubyConf 2022 description",
        "--start-date", "2022-11-15",
        "--end-date", "2022-11-17",
        "--date-precision", "year",
        "--announced-on", "2022-01-01",
        "--recordings-published-date", "2022-12-01",
        "--kind", "retreat",
        "--tickets-url", "https://example.com/tickets",
        "--website", "https://example.com/rubyconf-2022",
        "--original-website", "https://example.com/rubyconf-2022-archive",
        "--last-edition",
        "--timezone", "America/Chicago",
        "--online"]

      assert_file event_file_path do |content|
        assert_match(/title: "RubyConf 2022"/, content)
        assert_match(/description: |-\s+RubyConf 2022 description/, content)
        assert_match(/start_date: "2022-11-15"/, content)
        assert_match(/end_date: "2022-11-17"/, content)
        assert_match(/announced_on: "2022-01-01"/, content)
        assert_match(/recordings_published_date: "2022-12-01"/, content)
        assert_match(/year: 2022/, content)
        assert_match(/kind: "retreat"/, content)
        assert_match(/tickets_url: "https:\/\/example.com\/tickets"/, content)
        assert_match(/website: "https:\/\/example.com\/rubyconf-2022"/, content)
        assert_match(/original_website: "https:\/\/example.com\/rubyconf-2022-archive"/, content)
        assert_match(/timezone: "America\/Chicago"/, content)
        assert_match(/last_edition: true/, content)
        assert_match(/location: "online"/, content)
        assert_match(/coordinates: false/, content)
      end
    end
  end

  test "event with location and coordinates" do
    event_file_path = File.join(destination_root, "data/tropical-rb/2028/event.yml")
    eliminate_validated_file(file_path: event_file_path) do
      run_generator ["--force", # Force file creation
        "--event-series", "tropical-rb",
        "--event", "2028",
        "--title", "Tropical on Rails 2028",
        "--start-date", "2028-07-20",
        "--end-date", "2028-07-22",
        "--location", "Recife, PE, Brazil",
        "--latitude", "-8.04756",
        "--longitude", "-34.877"]

      assert_file event_file_path do |content|
        assert_match(/coordinates:\n\s+latitude: -8.04756/, content)
        assert_match(/longitude: -34.877/, content)
      end
    end
  end

  test "event with venue-name and venue-address creates venue.yml" do
    event_file_path = File.join(destination_root, "data/rubyconf/2025/event.yml")
    eliminate_validated_file(file_path: event_file_path) do
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
    end
  end

  def validate_event_file(path)
    Static::Validators::Validator.event_validator_classes.each do |validator|
      errors = validator.new(file_path: path).errors
      assert_empty errors, "#{validator} failed: #{errors.map { |error| error.to_h["message"] }.join(", ")}"
    end
  end

  def eliminate_validated_file(file_path:, &block)
    FileUtils.rm_rf(File.dirname(file_path))
    yield
    validate_event_file(file_path)
  ensure
    FileUtils.rm_rf(File.dirname(file_path))
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end
end
