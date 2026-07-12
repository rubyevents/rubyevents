require "test_helper"
require "generators/involvements/involvements_generator"

class InvolvementsGeneratorTest < Rails::Generators::TestCase
  tests InvolvementsGenerator
  setup do
    self.class.destination Dir.mktmpdir("involvements_generator", Rails.root.join("tmp").to_s)
  end
  teardown { FileUtils.remove_entry(destination_root) }

  test "generator with users argument" do
    file_path = File.join(destination_root, "data/xoruby/xoruby-salt-lake-city-2026/involvements.yml")

    assert_nothing_raised do
      run_generator [
        "--event", "xoruby-salt-lake-city-2026",
        "--name", "Organizer",
        "--users", "Jim Remsik", "Co-organizer"
      ]
    end

    assert_file file_path do |content|
      assert_match(/Organizer/, content)
      assert_match(/- Jim Remsik/, content)
      assert_match(/- Co-organizer/, content)
    end

    assert_file_passes_validations(file_path)
  end

  test "generator with organizers argument" do
    file_path = File.join(destination_root, "data/xoruby/xoruby-austin-2025/involvements.yml")
    assert_nothing_raised do
      run_generator [
        "--event", "xoruby-austin-2025",
        "--name", "Organizer",
        "--organisations", "Flagrant", "Another Org"
      ]
    end
    assert_file file_path do |content|
      assert_match(/Organizer/, content)
      assert_match(/- Flagrant/, content)
      assert_match(/- Another Org/, content)
    end
    assert_file_passes_validations(file_path)
  end

  test "generator with both arguments" do
    file_path = File.join(destination_root, "data/xoruby/2026/involvements.yml")
    assert_nothing_raised do
      run_generator [
        "--event-series", "xoruby",
        "--event", "2026",
        "--name", "Organizer",
        "--users", "Jim Remsik",
        "--organisations", "Flagrant"
      ]
    end
    assert_file file_path do |content|
      assert_match(/Organizer/, content)
      assert_match(/- Jim Remsik/, content)
      assert_match(/- Flagrant/, content)
    end
    assert_file_passes_validations(file_path)
  end

  test "generator updates existing involvements file" do
    file_path = File.join(destination_root, "data/xoruby/2027/involvements.yml")
    # First run to create the file
    run_generator [
      "--event-series", "xoruby",
      "--event", "2027",
      "--name", "Organizer",
      "--users", "Jim Remsik"
    ]

    # Second run to update the file with new users
    assert_nothing_raised do
      run_generator [
        "--event-series", "xoruby",
        "--event", "2027",
        "--name", "Organizer",
        "--organisations", "Flagrant"
      ]
    end

    assert_file file_path do |content|
      assert_match(/Organizer/, content)
      assert_match(/- Flagrant/, content)
      refute_match(/- Jim Remsik/, content) # Ensure the old user is removed
    end

    assert_file_passes_validations(file_path)
  end

  test "generator creates new involvement entry if name is different" do
    file_path = File.join(destination_root, "data/xoruby/2028/involvements.yml")
    # First run to create the file with one involvement
    run_generator [
      "--event-series", "xoruby",
      "--event", "2028",
      "--name", "Organizer",
      "--users", "Jim Remsik"
    ]
    run_generator [
      "--event-series", "xoruby",
      "--event", "2028",
      "--name", "Volunteer",
      "--users", "Alice Smith"
    ]

    assert_file file_path do |content|
      assert_match(/Organizer/, content)
      assert_match(/- Jim Remsik/, content)
      assert_match(/Volunteer/, content)
      assert_match(/- Alice Smith/, content)
    end

    assert_file_passes_validations(file_path)
  end

  def assert_file_passes_validations(file_path, msg = nil)
    [Static::Validators::Schema].each do |validator|
      errors = validator.new(file_path:).validate
      assert_empty errors, msg || "#{validator} failed: #{errors.map { |error| error.to_h["message"] }.join(", ")}"
    end
  end
end
