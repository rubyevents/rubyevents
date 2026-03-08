require "test_helper"
require "generators/event/event_generator"
require "#{Rails.root}/app/schemas/event_schema"
require "json_schemer"
require "yaml"

class EventGeneratorTest < Rails::Generators::TestCase
  tests EventGenerator
  destination Rails.root.join("tmp/generators/event")

  test "creates event.yml in correct directory" do
    assert_nothing_raised do
      run_generator ["--event-series", "rubyconf", "--event", "2024", "--name", "RubyConf 2024"]
    end

    assert_file "data/rubyconf/2024/event.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end

    File.delete(File.join(destination_root, "data/rubyconf/2024/event.yml"))
  end

  test "creates venue.yml" do
    run_generator ["--event-series", "rubyconf", "--event", "2025", "--name", "RubyConf 2025", "--venue-name", "RubyConf 2025 Venue", "--venue-address", "123 Main St, Test City"]
    assert_file "data/rubyconf/2025/venue.yml" do |content|
      assert_match(/RubyConf 2025 Venue/, content)
      assert_match(/123 Main St/, content)
    end

    File.delete(File.join(destination_root, "data/rubyconf/2025/event.yml"))
    File.delete(File.join(destination_root, "data/rubyconf/2025/venue.yml"))
  end

  test "event.yml passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2026", "--name", "RubyConf 2026"]

    event_file_path = File.join(destination_root, "data/rubyconf/2026/event.yml")
    validate_event_schema event_file_path

    File.delete event_file_path
  end

  test "event with all flags passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2027", "--name", "RubyConf 2027", "--kind", "retreat", "--hybrid", "--last-edition"]

    event_file_path = File.join(destination_root, "data/rubyconf/2027/event.yml")
    validate_event_schema event_file_path
    File.delete event_file_path
  end

  test "event with all flags off passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2028", "--name", "RubyConf 2028", "--no-hybrid", "--no-last-edition"]

    event_file_path = File.join(destination_root, "data/rubyconf/2028/event.yml")
    validate_event_schema event_file_path

    File.delete event_file_path
  end

  def validate_event_schema(file_path)
    data = YAML.load_file(file_path)

    schema = JSON.parse(EventSchema.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    errors = schemer.validate(data).to_a
    assert_empty errors, "Event YAML does not conform to schema: #{errors.join(", ")}"
  end
end
