require "test_helper"
require "generators/schedule/schedule_generator"

class ScheduleGeneratorTest < Rails::Generators::TestCase
  tests ScheduleGenerator
  destination Rails.root.join("tmp/generators/schedule")

  test "creates schedule.yml in correct directory" do
    assert_nothing_raised do
      run_generator ["--event-series", "rbqconf", "--event", "rbqconf-2026"]
    end

    assert_file "data/rbqconf/rbqconf-2026/schedule.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end

    schedule_file_path = File.join(destination_root, "data/rbqconf/rbqconf-2026/schedule.yml")
    validate_schedule_schema schedule_file_path

    File.delete schedule_file_path
  end

  def validate_schedule_schema(file_path)
    require "#{Rails.root}/app/schemas/schedule_schema"

    validator = Static::Validators::Schema.new(file_path: file_path)
    assert_empty validator.errors, "Schedule YAML does not conform to schema: #{validator.errors.map { |e| e.to_h["message"] }.join(", ")}"
  end
end
