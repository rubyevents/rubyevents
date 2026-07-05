require "test_helper"
require "generators/involvements/involvements_generator"

class InvolvementsGeneratorTest < Rails::Generators::TestCase
  tests InvolvementsGenerator
  destination Rails.root.join("tmp/generators/involvements")
  setup :prepare_destination

  test "generator with minimum arguments" do
    file_path = File.join(destination_root, "data/xoruby/xoruby-salt-lake-city-2026/involvements.yml")

    eliminate_validated_file(file_path:) do
      assert_nothing_raised do
        run_generator [
          "--event", "xoruby-salt-lake-city-2026",
          "--name", "Organizers"
        ]
      end

      assert_file "data/xoruby/xoruby-salt-lake-city-2026/involvements.yml" do |content|
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
