require "test_helper"
require "generators/sponsors/sponsors_generator"
require "#{Rails.root}/app/schemas/sponsors_schema"
require "json_schemer"
require "yaml"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  tests SponsorsGenerator
  destination Rails.root.join("tmp/generators")
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
  end

  test "sponsors.yml passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2024"]

    sponsor_file_path = File.join(destination_root, "data/rubyconf/2024/sponsors.yml")
    data = YAML.load_file(sponsor_file_path)

    schema = JSON.parse(SponsorsSchema.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    errors = []
    Array(data).each_with_index do |item, index|
      errs = schemer.validate(item).to_a
      errors.append(errs) unless errs.empty?
    end

    assert_empty errors, "Sponsors YAML does not conform to schema: #{errors.join(", ")}"
  end
end
