require "test_helper"
require "generators/cfp/cfp_generator"
require "#{Rails.root}/app/schemas/cfp_schema"

class CFPGeneratorTest < Rails::Generators::TestCase
  tests CfpGenerator
  setup do
    self.class.destination Dir.mktmpdir("cfp_generator", Rails.root.join("tmp").to_s)
  end
  teardown { FileUtils.remove_entry(destination_root) }

  test "creates cfp.yml with valid yaml with no params" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2021/cfp.yml")
    assert_nothing_raised do
      run_generator [
        "--event-series", "rubyconf",
        "--event", "2021"
      ]
    end

    assert_valid_file cfp_file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
    end
  end

  test "creates cfp.yml with valid yaml with all params" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2022/cfp.yml")
    run_generator [
      "--event-series", "rubyconf",
      "--event", "2022",
      "--name", "Call for Proposals",
      "--link", "https://example.com/cfp",
      "--open-date", "2022-01-01",
      "--close-date", "2022-02-01"
    ]

    assert_valid_file cfp_file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
      assert_match(%r{link: "https://example.com/cfp"}, content)
      assert_match(/open_date: "2022-01-01"/, content)
      assert_match(/close_date: "2022-02-01"/, content)
    end
  end

  test "update cfp.yml if called twice with same name" do
    file_path = File.join(destination_root, "data/rubyconf/2023/cfp.yml")
    run_generator [
      "--event-series", "rubyconf",
      "--event", "2023",
      "--name", "Call for Proposals"
    ]
    assert_valid_file file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
      assert_match(/link: "" # TODO/, content)
    end

    run_generator ["--event-series", "rubyconf", "--event", "2023", "--name", "Call for Proposals", "--link", "https://example.com/cfp"]

    assert_valid_file file_path do |content|
      assert_match(%r{link: "https://example.com/cfp"}, content)
      assert_no_match(/link: "" # TODO/, content)
    end
  end

  test "append to cfp.yml if called with a different name" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2024/cfp.yml")
    run_generator ["--event-series", "rubyconf", "--event", "2024"]
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--name", "CFP TWO"]

    assert_valid_file cfp_file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
      assert_match(/name: "CFP TWO"/, content)
    end
  end

  def assert_valid_file(file_path, msg = nil, &block)
    errors = Static::Validators::Validator.cfp_validator_classes.flat_map do |validator|
      validator.new(file_path:).errors
    end
    assert_empty errors, msg || errors.map { |e| e.to_h["message"] }.join(", ")
    assert_file file_path, msg, &block
  end
end
