require "test_helper"
require "generators/cfp/cfp_generator"
require "#{Rails.root}/app/schemas/cfp_schema"

class CFPGeneratorTest < Rails::Generators::TestCase
  tests CfpGenerator
  destination Rails.root.join("tmp/generators/cfp")

  test "generator runs without errors" do
    assert_nothing_raised do
      run_generator ["--event-series", "rubyconf", "--event", "2021"]
    end
  end

  test "creates cfp.yml with valid yaml with no params" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2021/cfp.yml")
    eliminate_validated_file(file_path: cfp_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2021"]

      assert_file cfp_file_path do |content|
        assert_match(/\S/, content) # Verify file has content
      end
    end
  end

  test "creates cfp.yml with valid yaml with all params" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2022/cfp.yml")
    eliminate_validated_file(file_path: cfp_file_path) do
      run_generator [
        "--event-series", "rubyconf",
        "--event", "2022",
        "--name", "Call for Proposals",
        "--link", "https://example.com/cfp",
        "--open-date", "2022-01-01",
        "--close-date", "2022-02-01"
      ]

      assert_file cfp_file_path do |content|
        assert_match(/name: "Call for Proposals"/, content)
        assert_match(%r{link: "https://example.com/cfp"}, content)
        assert_match(/open_date: "2022-01-01"/, content)
        assert_match(/close_date: "2022-02-01"/, content)
      end
    end
  end

  test "update cfp.yml if called twice with same name" do
    file_path = File.join(destination_root, "data/rubyconf/2023/cfp.yml")
    eliminate_validated_file(file_path:) do
      run_generator [
        "--event-series", "rubyconf",
        "--event", "2023",
        "--name", "Call for Proposals"
      ]
      assert_file file_path do |content|
        assert_match(/name: "Call for Proposals"/, content)
        assert_match(/link: "" # TODO/, content)
      end

      run_generator ["--event-series", "rubyconf", "--event", "2023", "--name", "Call for Proposals", "--link", "https://example.com/cfp"]

      assert_file file_path do |content|
        assert_match(%r{link: "https://example.com/cfp"}, content)
        assert_no_match(/link: "" # TODO/, content)
      end
    end
  end

  test "append to cfp.yml if called with a different name" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2024/cfp.yml")
    eliminate_validated_file(file_path: cfp_file_path) do
      run_generator ["--event-series", "rubyconf", "--event", "2024"]
      run_generator ["--event-series", "rubyconf", "--event", "2024", "--name", "CFP TWO"]

      assert_file cfp_file_path do |content|
        assert_match(/name: "Call for Proposals"/, content)
        assert_match(/name: "CFP TWO"/, content)
      end
    end
  end

  def validate_cfp_file(path)
    errors = Static::Validators::SchemaArray.new(file_path: path).validate
    assert_empty errors, "CFP YAML does not conform to schema: #{errors.join(", ")}"
  end

  def eliminate_validated_file(file_path:, &block)
    File.delete(file_path) if File.exist?(file_path)
    yield
    validate_cfp_file(file_path)
  ensure
    File.delete(file_path) if File.exist?(file_path)
  end
end
