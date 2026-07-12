require "test_helper"
require "generators/schedule/schedule_generator"

class ScheduleGeneratorTest < Rails::Generators::TestCase
  tests ScheduleGenerator
  setup do
    self.class.destination Dir.mktmpdir("schedule_generator", Rails.root.join("tmp").to_s)
  end
  teardown { FileUtils.remove_entry(destination_root) }

  test "creates schedule.yml in correct directory" do
    schedule_file_path = File.join(destination_root, "data/rbqconf/rbqconf-2026/schedule.yml")
    assert_nothing_raised do
      run_generator ["--event-series", "rbqconf", "--event", "rbqconf-2026"]
    end

    assert_file "data/rbqconf/rbqconf-2026/schedule.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end

    assert_file_passes_validations(schedule_file_path)
  end

  def assert_file_passes_validations(file_path, msg = nil)
    [Static::Validators::Schema].each do |validator|
      errors = validator.new(file_path:).validate
      assert_empty errors, msg || "#{validator} failed: #{errors.map { |error| error.to_h["message"] }.join(", ")}"
    end
  end
end
