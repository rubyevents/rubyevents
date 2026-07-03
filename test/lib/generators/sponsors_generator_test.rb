require "test_helper"
require "generators/sponsors/sponsors_generator"
require "#{Rails.root}/app/schemas/sponsors_schema"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  tests SponsorsGenerator
  destination Rails.root.join("tmp/generators/sponsors")
  setup :prepare_destination

  test "generator populates sponsors.yml with arguments" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")

    eliminate_validated_file(file_path:) do
      assert_nothing_raised do
        run_generator ["typesense:platinum", "braze:platinum", "AppSignal:Gold", "--event_series", "tropicalrb", "--event", "tropical-on-rails-2026"]
      end

      assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
        assert_match(/platinum/, content, "platinum Tier missing")
        assert_match(/Gold/, content, "Gold Tier missing")
        assert_match(/typesense/, content, "typesense sponsor missing")
        assert_match(/appsignal/, content, "AppSignal sponsor missing")
      end
    end
  end

  test "minimal sponsor passes schema validation" do
    file_path = File.join(destination_root, "data/rubyconf/2024/sponsors.yml")
    eliminate_validated_file(file_path:) do
      run_generator ["--event-series", "rubyconf", "--event", "2024"]
    end
  end

  def validate_sponsor_file(path)
    errors = Static::Validators::SchemaArray.new(file_path: path).validate
    assert_empty errors, "Sponsors YAML does not conform to schema: #{errors.join(", ")}"
  end

  def eliminate_validated_file(file_path:, &block)
    File.delete(file_path) if File.exist?(file_path)
    yield
    validate_sponsor_file(file_path)
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
