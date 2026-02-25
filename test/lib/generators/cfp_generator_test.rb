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
      run_generator ["--event-series", "rubyconf", "--event", "2021"]
    end
  end

  test "creates cfp.yml with valid yaml" do
    run_generator ["--event-series", "rubyconf", "--event", "2022"]

    assert_file "data/rubyconf/2022/cfp.yml" do |content|
      assert_match(/\S/, content) # Verify file has content
    end

    cfp_file_path = File.join(destination_root, "data/rubyconf/2022/cfp.yml")
    validate_cfp_file(cfp_file_path)
  end

  test "update cfp.yml if called twice" do
    run_generator ["--event-series", "rubyconf", "--event", "2023"]
    run_generator ["--event-series", "rubyconf", "--event", "2023", "--name", "Call for Proposals", "--link", "https://example.com/cfp"]

    assert_file "data/rubyconf/2023/cfp.yml" do |content|
      assert_match(%r{https://example.com/cfp}, content)
      assert_no_match(%r{https://TODO.example.com/cfp}, content)
    end

    cfp_file_path = File.join(destination_root, "data/rubyconf/2023/cfp.yml")
    validate_cfp_file(cfp_file_path)
  end

  test "append to cfp.yml if called with a different name" do
    run_generator ["--event-series", "rubyconf", "--event", "2024"]
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--name", "CFP TWO"]

    assert_file "data/rubyconf/2024/cfp.yml" do |content|
      assert_match(/Call for Proposals/, content)
      assert_match(/CFP TWO/, content)
    end

    cfp_file_path = File.join(destination_root, "data/rubyconf/2024/cfp.yml")
    validate_cfp_file(cfp_file_path)
  end

  def validate_cfp_file(path)
    data = YAML.load_file(path)

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
