require "test_helper"
require "generators/cfp/cfp_generator"
require "#{Rails.root}/app/schemas/cfp_schema"
require "json_schemer"
require "yaml"

class CFPGeneratorTest < Rails::Generators::TestCase
  tests CfpGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator ["--event-series", "rubyconf", "--event", "2024"]
    end
  end

  test "creates cfp.yml in correct directory" do
    run_generator ["--event-series", "rubyconf", "--event", "2024"]

    assert_file "data/rubyconf/2024/cfp.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end
  end

  test "cfp.yml passes schema validation" do
    run_generator ["--event-series", "rubyconf", "--event", "2024"]

    cfp_file_path = File.join(destination_root, "data/rubyconf/2024/cfp.yml")
    data = YAML.load_file(cfp_file_path)

    schema = JSON.parse(CFPSchema.new.to_json_schema[:schema].to_json)
    schemer = JSONSchemer.schema(schema)

    errors = []
    Array(data).each_with_index do |item, index|
      errs = schemer.validate(item).to_a
      errors.append(errs) unless errs.empty?
    end

    assert_empty errors, "CFP YAML does not conform to schema: #{errors.join(", ")}"
  end
end
