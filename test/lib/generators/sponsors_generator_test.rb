require "test_helper"
require "generators/sponsors/sponsors_generator"
require "#{Rails.root}/app/schemas/sponsors_schema"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  tests SponsorsGenerator
  setup do
    self.class.destination Dir.mktmpdir("sponsors_generator", Rails.root.join("tmp").to_s)
  end
  teardown { FileUtils.remove_entry(destination_root) }

  test "generator creates an empty sponsors file with default tier" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2021/sponsors.yml")
    assert_nothing_raised do
      run_generator [
        "--event-series", "tropicalrb",
        "--event", "tropical-on-rails-2021"
      ]
    end

    assert_valid_file file_path do |content|
      assert_match(/name: "Sponsors"/, content)
    end
  end

  test "generator creates an empty sponsors file with specified tiers" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2022/sponsors.yml")
    assert_nothing_raised do
      run_generator [
        "--tiers", "Platinum,Gold,Silver",
        "--event-series", "tropicalrb",
        "--event", "tropical-on-rails-2022"
      ]
    end

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"/, content)
      assert_match(/name: "Gold"/, content)
      assert_match(/name: "Silver"/, content)
    end
  end

  test "generator creates a sponsor with no tiers and no logo" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2023/sponsors.yml")
    assert_nothing_raised do
      run_generator [
        "--event-series", "tropicalrb",
        "--event", "tropical-on-rails-2023",
        "--name", "Typesense",
        "--website", "https://typesense.org"
      ]
    end

    assert_valid_file file_path do |content|
      assert_match(/name: "Sponsors"/, content)
    end
  end

  test "generator creates a sponsors.yml and adds a first sponsor" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2024/sponsors.yml")
    assert_nothing_raised do
      run_generator ["--tiers", "Platinum,Gold,Silver",
        "--event-series", "tropicalrb",
        "--event", "tropical-on-rails-2024",
        "--name", "Typesense",
        "--website", "https://typesense.org",
        "--logo-url", "https://typesense.org/logo.png",
        "--tier", "Platinum"]
    end

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"/, content, "Platinum Tier missing")
      assert_match(/Gold/, content, "Gold Tier missing")
      assert_match(/Silver/, content, "Silver Tier missing")
      assert_match(/Typesense/, content, "Typesense sponsor missing")
      assert_match(/https:\/\/typesense.org/, content, "typesense website missing")
      assert_match(/https:\/\/typesense.org\/logo.png/, content, "typesense logo URL missing")
    end
  end

  test "generator adds a new sponsor to a tier with existing sponsors" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2025/sponsors.yml")
    run_generator ["--tiers", "Platinum,Gold,Silver",
      "--event", "tropical-on-rails-2025",
      "--name", "Typesense",
      "--website", "https://typesense.org",
      "--logo-url", "https://typesense.org/logo.png",
      "--tier", "Platinum"]

    assert_file file_path do |content|
      assert_match(/name: Typesense/, content)
      assert_match(/website: https:\/\/typesense.org/, content)
      assert_match(/logo_url: https:\/\/typesense.org\/logo.png/, content)
    end

    run_generator ["--event", "tropical-on-rails-2025",
      "--name", "Braze",
      "--website", "https://braze.com",
      "--logo-url", "https://braze.com/logo.png",
      "--tier", "Platinum"]

    assert_valid_file file_path do |content|
      assert_match(/name: Braze/, content)
      assert_match(/name: Typesense/, content)
    end
  end

  test "generator updates an existing sponsor's information" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")
    run_generator ["--tiers", "Platinum,Gold,Silver",
      "--event", "tropical-on-rails-2026",
      "--name", "Typesense",
      "--website", "https://typesense.org",
      "--logo-url", "https://typesense.org/logo.png",
      "--tier", "Gold"]

    assert_file file_path do |content|
      assert_match(/name: Typesense/, content)
    end

    run_generator ["--event", "tropical-on-rails-2026",
      "--name", "Typesense",
      "--badge", "Wifi Sponsor"]

    assert_valid_file file_path do |content|
      assert_match(/name: Typesense/, content)
      assert_match(/website: https:\/\/typesense.org/, content)
      assert_match(/logo_url: https:\/\/typesense.org\/logo.png/, content)
      assert_match(/badge: Wifi Sponsor/, content)
    end
  end

  test "generator pulls sponsor information from other sponsor files" do
    skip "Implement LATER :)"
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")
    run_generator ["--tiers", "Platinum,Gold,Silver",
      "--event", "tropical-on-rails-2026",
      "--name", "Typesense",
      "--tier", "Gold"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Typesense"/, content)
      assert_match(/website: "https:\/\/typesense.org"/, content)
      assert_match(/logo_url: "https:\/\/typesense.org\/logo.png"/, content)
    end
  end

  def assert_valid_file(file_path, msg = nil, &block)
    errors = Static::Validators::Validator.sponsor_validator_classes.flat_map do |validator|
      validator.new(file_path:).errors
    end
    assert_empty errors, msg || errors.map { |e| e.to_h["message"] }.join(", ")
    assert_file file_path, msg, &block
  end
end
