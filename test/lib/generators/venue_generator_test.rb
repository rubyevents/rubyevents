require "test_helper"
require "generators/venue/venue_generator"
require "#{Rails.root}/app/schemas/venue_schema"
require "json_schemer"
require "yaml"

class VenueGeneratorTest < Rails::Generators::TestCase
  tests VenueGenerator
  destination Rails.root.join("tmp/generators/venue")

  test "creates venue.yml in correct directory" do
    assert_nothing_raised do
      run_generator ["--event", "rubyconf-2001"]
    end

    assert_file "data/rubyconf/rubyconf-2001/venue.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end

    File.delete File.join(destination_root, "data/rubyconf/rubyconf-2001/venue.yml")
  end

  test "venue.yml passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2002"]

    venue_file_path = File.join(destination_root, "data/rubyconf/2002/venue.yml")
    validate_venue_schema venue_file_path

    File.delete venue_file_path
  end

  test "venue with all flags passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2003", "--hotel", "--nearby", "--locations", "--rooms", "--spaces", "--accessibility"]

    venue_file_path = File.join(destination_root, "data/rubyconf/2003/venue.yml")
    validate_venue_schema venue_file_path

    File.delete venue_file_path
  end

  test "venue with all flags off passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2004", "--no-hotel", "--no-nearby", "--no-locations", "--no-rooms", "--no-spaces", "--no-accessibility"]

    venue_file_path = File.join(destination_root, "data/rubyconf/2004/venue.yml")
    validate_venue_schema venue_file_path

    File.delete venue_file_path
  end

  def validate_venue_schema(file_path)
    data = YAML.load_file(file_path)

    schema = JSON.parse(VenueSchema.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    errors = schemer.validate(data).to_a
    assert_empty errors, "Venue YAML does not conform to schema: #{errors.join(", ")}"
  end
end
