require "test_helper"
require "generators/sponsors/sponsors_generator"
require "#{Rails.root}/app/schemas/sponsors_schema"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  tests SponsorsGenerator
  destination Rails.root.join("tmp/generators/sponsors")
  setup :prepare_destination

  test "generator populates sponsors.yml with arguments" do
    assert_nothing_raised do
      run_generator ["typesense:platinum", "braze:platinum", "AppSignal:Gold", "--event_series", "tropicalrb", "--event", "tropical-on-rails-2026"]
    end

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/platinum/, content, "platinum Tier missing")
      assert_match(/Gold/, content, "Gold Tier missing")
      assert_match(/typesense/, content, "typesense sponsor missing")
      assert_match(/appsignal/, content, "AppSignal sponsor missing")
    end

    File.delete File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")
  end

  test "sponsors.yml passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2024"]

    sponsor_file_path = File.join(destination_root, "data/rubyconf/2024/sponsors.yml")
    errors = Static::Validators::SchemaArray.new(file_path: sponsor_file_path).validate
    assert_empty errors, "Sponsors YAML does not conform to schema: #{errors.join(", ")}"

    File.delete sponsor_file_path
  end
end
