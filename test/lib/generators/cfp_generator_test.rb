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

    assert_file cfp_file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
    end
    assert_file_passes_validations(cfp_file_path)
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

    assert_file cfp_file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
      assert_match(%r{link: "https://example.com/cfp"}, content)
      assert_match(/open_date: "2022-01-01"/, content)
      assert_match(/close_date: "2022-02-01"/, content)
    end
    assert_file_passes_validations(cfp_file_path)
  end

  test "update cfp.yml if called twice with same name" do
    file_path = File.join(destination_root, "data/rubyconf/2023/cfp.yml")
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

    assert_file_passes_validations(file_path)
  end

  test "append to cfp.yml if called with a different name" do
    cfp_file_path = File.join(destination_root, "data/rubyconf/2024/cfp.yml")
    run_generator ["--event-series", "rubyconf", "--event", "2024"]
    run_generator ["--event-series", "rubyconf", "--event", "2024", "--name", "CFP TWO"]

    assert_file cfp_file_path do |content|
      assert_match(/name: "Call for Proposals"/, content)
      assert_match(/name: "CFP TWO"/, content)
    end
    assert_file_passes_validations(cfp_file_path)
  end

  def assert_file_passes_validations(file_path, msg = nil)
    [Static::Validators::Schema].each do |validator|
      errors = validator.new(file_path:).validate
      assert_empty errors, msg || "#{validator} failed: #{errors.map { |error| error.to_h["message"] }.join(", ")}"
    end
  end
end
