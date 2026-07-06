require "test_helper"
require "generators/involvements/involvements_generator"

class InvolvementsGeneratorTest < Rails::Generators::TestCase
  tests InvolvementsGenerator
  destination Rails.root.join("tmp/generators/involvements")
  setup :prepare_destination

  test "generator with users argument" do
    file_path = File.join(destination_root, "data/xoruby/xoruby-salt-lake-city-2026/involvements.yml")

    eliminate_validated_file(file_path:) do
      assert_nothing_raised do
        run_generator [
          "--event", "xoruby-salt-lake-city-2026",
          "--name", "Organizer",
          "--users", "Jim Remsik", "Co-organizer"
        ]
      end

      assert_file file_path do |content|
        assert_match(/Organizers/, content)
        assert_match(/- Jim Remsik/, content)
        assert_match(/- Co-organizer/, content)
      end
    end
  end

  test "generator with organizers argument" do
    file_path = File.join(destination_root, "data/xoruby/xoruby-austin-2025/involvements.yml")
    eliminate_validated_file(file_path:) do
      assert_nothing_raised do
        run_generator [
          "--event", "xoruby-austin-2025",
          "--name", "Organizer",
          "--organisations", "Flagrant", "Another Org"
        ]
      end
      assert_file file_path do |content|
        assert_match(/Organizers/, content)
        assert_match(/- Flagrant/, content)
        assert_match(/- Another Org/, content)
      end
    end
  end

  test "generator with both arguments" do
    file_path = File.join(destination_root, "data/xoruby/2026/involvements.yml")
    eliminate_validated_file(file_path:) do
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
        assert_match(/Organizers/, content)
        assert_match(/- Jim Remsik/, content)
        assert_match(/- Flagrant/, content)
      end
    end
  end

  def validate_involvements_file(file_path)
    [Static::Validators::SchemaArray].each do |validator|
      errors = validator.new(file_path:).validate
      assert_empty errors, "#{validator} failed: #{errors.map { |error| error.to_h["message"] }.join(", ")}"
    end
  end

  def eliminate_validated_file(file_path:, &block)
    File.delete(file_path) if File.exist?(file_path)
    yield
    validate_involvements_file(file_path)
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
