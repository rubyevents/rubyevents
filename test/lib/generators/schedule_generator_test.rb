require "test_helper"
require "generators/schedule/schedule_generator"

class ScheduleGeneratorTest < Rails::Generators::TestCase
  tests ScheduleGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "creates schedule.yml in correct directory" do
    assert_nothing_raised do
      run_generator ["--event-series", "rbqconf", "--event", "rbqconf-2026"]
    end

    assert_file "data/rbqconf/rbqconf-2026/schedule.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end

    validate_schedule_schema File.join(destination_root, "data/rbqconf/rbqconf-2026/schedule.yml")
  end

  def validate_schedule_schema(file_path)
    require "#{Rails.root}/app/schemas/schedule_schema"
    require "json_schemer"
    require "yaml"

    data = YAML.load_file(file_path)
    schema = JSON.parse(ScheduleSchema.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)
    errors = schemer.validate(data).to_a
    assert_empty errors, "Schedule YAML does not conform to schema: #{errors.join(", ")}"
  end
end
