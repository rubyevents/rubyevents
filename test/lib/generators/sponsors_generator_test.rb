require "test_helper"
require "generators/sponsors/sponsors_generator"
require "#{Rails.root}/app/schemas/sponsors_schema"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  tests SponsorsGenerator
  destination Rails.root.join("tmp/generators/sponsors")
  setup :prepare_destination

  test "generator creates an empty sponsors file with specified tiers" do
    assert_nothing_raised do
      run_generator ["--tiers", "Platinum,Gold,Silver",
        "--event", "tropical-on-rails-2026"]
    end
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/name: "Platinum"/, content, "Platinum Tier missing")
      assert_match(/Gold/, content, "Gold Tier missing")
      assert_match(/Silver/, content, "Silver Tier missing")
    end

    sponsors_file_passes_validations(file_path:)

    File.delete file_path
  end

  test "generator creates a sponsors.yml and adds a first sponsor" do
    skip "BLOCKED - cannot add to empty array"
    assert_nothing_raised do
      run_generator ["--tiers", "Platinum,Gold,Silver",
        "--event", "tropical-on-rails-2026",
        "--name", "Typesense",
        "--website", "https://typesense.org",
        "--logo-url", "https://typesense.org/logo.png",
        "--tier", "Platinum"]
    end
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/name: "Platinum"/, content, "Platinum Tier missing")
      assert_match(/Gold/, content, "Gold Tier missing")
      assert_match(/Silver/, content, "Silver Tier missing")
      assert_match(/Typesense/, content, "Typesense sponsor missing")
      assert_match(/https:\/\/typesense.org/, content, "typesense website missing")
      assert_match(/https:\/\/typesense.org\/logo.png/, content, "typesense logo URL missing")
    end

    sponsors_file_passes_validations(file_path:)

    File.delete file_path
  end

  test "generator adds a new sponsor to a tier with existing sponsors" do
    skip "Cannot generate file with empty sponsors array yet, so this test depends on the previous one passing :["
    run_generator ["--tiers", "Platinum,Gold,Silver",
      "--event", "tropical-on-rails-2026",
      "--name", "Typesense",
      "--website", "https://typesense.org",
      "--logo-url", "https://typesense.org/logo.png",
      "--tier", "Platinum"]
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/Typesense/, content, "Typesense sponsor not added to the correct tier")
    end

    run_generator ["--event", "tropical-on-rails-2026",
      "--name", "Braze",
      "--website", "https://braze.com",
      "--logo-url", "https://braze.com/logo.png",
      "--tier", "Platinum"]

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/Braze/, content, "Braze sponsor not added")
      assert_match(/Typesense/, content, "Typesense sponsor removed")
    end

    sponsors_file_passes_validations(file_path:)

    File.delete file_path
  end

  test "generator updates an existing sponsor's information" do
    skip "Coming soon"

    run_generator ["--tiers", "Platinum,Gold,Silver",
      "--event", "tropical-on-rails-2026",
      "--name", "Typesense",
      "--website", "https://typesense.org",
      "--logo-url", "https://typesense.org/logo.png",
      "--tier", "Gold"]
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/Typesense/, content, "Typesense sponsor not added")
    end

    run_generator ["--event", "tropical-on-rails-2026",
      "--name", "Typesense",
      "--tier", "Platinum"]

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/Typesense/, content, "Typesense sponsor not found in Platinum tier")
    end

    sponsors_file_passes_validations(file_path:)

    File.delete file_path
  end

  test "generator pulls sponsor information from other sponsor files" do
    skip "Implement LATER :)"
    run_generator ["--tiers", "Platinum,Gold,Silver",
      "--event", "tropical-on-rails-2026", "--name", "Typesense", "--tier", "Gold"]
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")

    assert_file "data/tropicalrb/tropical-on-rails-2026/sponsors.yml" do |content|
      assert_match(/Typesense/, content, "Typesense sponsor not found in Gold tier")
      assert_match(/https:\/\/typesense.org/, content, "Typesense website not found")
      assert_match(/https:\/\/typesense.org\/logo.png/, content, "Typesense logo URL not found")
    end

    sponsors_file_passes_validations(file_path:)

    File.delete file_path
  end

  def sponsors_file_passes_validations(file_path:)
    errors = Static::Validators::SchemaArray.new(file_path: file_path).validate
    assert_empty errors, "Sponsors YAML does not conform to schema: #{errors.join(", ")}"
  end
end
