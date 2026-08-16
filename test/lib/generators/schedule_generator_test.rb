require "test_helper"
require "generators/schedule/schedule_generator"

class ScheduleGeneratorTest < Rails::Generators::TestCase
  tests ScheduleGenerator
  setup do
    self.class.destination Dir.mktmpdir("schedule_generator", Rails.root.join("tmp").to_s)
  end
  teardown { FileUtils.remove_entry(destination_root) }

  test "creates schedule.yml in correct directory" do
    File.join(destination_root, "data/rbqconf/rbqconf-2026/schedule.yml")
    assert_nothing_raised do
      run_generator ["--event-series", "rbqconf", "--event", "rbqconf-2026"]
    end

    assert_valid_file "data/rbqconf/rbqconf-2026/schedule.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end
  end

  def assert_valid_file(file_path, msg = nil, &block)
    errors = Static::Validators::Validator.schedule_validator_classes.flat_map do |validator|
      validator.new(file_path:).errors
    end
    assert_empty errors, msg || errors.map { |e| e.to_h["message"] }.join(", ")
    assert_file file_path, msg, &block
  end
end
