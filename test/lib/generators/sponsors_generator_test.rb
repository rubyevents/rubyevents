require "test_helper"
require "generators/sponsors/sponsors_generator"

class SponsorsGeneratorTest < Rails::Generators::TestCase
  include StaticOrganizationsSandbox

  tests SponsorsGenerator

  setup do
    self.class.destination Dir.mktmpdir("sponsors_generator", Rails.root.join("tmp").to_s)
    sandbox_organizations({slug: "typesense", name: "Typesense", website: "https://typesense.org", aliases: [{"name" => "TypeSense", "slug" => "type-sense"}]})
  end

  teardown { FileUtils.remove_entry(destination_root) }

  test "generator creates an empty sponsors file with default tier" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2021/sponsors.yml")

    run_generator ["--event-series", "tropicalrb", "--event", "tropical-on-rails-2021"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Sponsors"/, content)
    end
  end

  test "generator creates an empty sponsors file with specified tiers" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2022/sponsors.yml")

    run_generator ["--tiers", "Platinum,Gold,Silver", "--event-series", "tropicalrb", "--event", "tropical-on-rails-2022"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"/, content)
      assert_match(/name: "Gold"/, content)
      assert_match(/name: "Silver"/, content)
    end
  end

  test "generator adds a known organization by slug, resolving aliases" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2023/sponsors.yml")

    run_generator ["--event-series", "tropicalrb", "--event", "tropical-on-rails-2023", "--slug", "type-sense", "--tier", "Sponsors"]

    assert_valid_file file_path do |content|
      assert_match(/- slug: "?typesense"?$/, content)
      assert_no_match(/name: "Typesense"/, content)
    end
    assert_equal 1, Static::Organization.count
  end

  test "generator adds a new organization to organizations.yml when given a name" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2024/sponsors.yml")

    run_generator ["--tiers", "Platinum,Gold,Silver", "--event-series", "tropicalrb", "--event", "tropical-on-rails-2024",
      "--name", "Planet Argon", "--website", "https://www.planetargon.com", "--logo-url", "https://www.planetargon.com/logo.png", "--tier", "Platinum"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"\n\s+level: 0\n\s+sponsors:\n\s+- slug: "?planet-argon"?/, content)
      assert_no_match(/planetargon.com/, content)
    end

    organization = Static::Organization.find_by(slug: "planet-argon")
    assert_equal "Planet Argon", organization.name
    assert_equal "https://www.planetargon.com", organization.website
    assert_equal "https://www.planetargon.com/logo.png", organization.logo_url
  end

  test "generator fails for an unknown slug without a name" do
    error = capture(:stderr) { run_generator ["--event-series", "tropicalrb", "--event", "tropical-on-rails-2023", "--slug", "nobody", "--tier", "Sponsors"] }

    assert_match(/No organization with slug 'nobody'/, error)
    assert_no_match(/nobody/, File.read(File.join(destination_root, "data/tropicalrb/tropical-on-rails-2023/sponsors.yml")))
  end

  test "generator adds a new sponsor to a tier with existing sponsors" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2025/sponsors.yml")
    run_generator ["--tiers", "Platinum,Gold,Silver", "--event", "tropical-on-rails-2025", "--slug", "typesense", "--tier", "Platinum"]

    run_generator ["--event", "tropical-on-rails-2025", "--name", "Braze", "--website", "https://braze.com", "--tier", "Platinum"]

    assert_valid_file file_path do |content|
      assert_match(/- slug: "?typesense"?/, content)
      assert_match(/- slug: "?braze"?/, content)
    end
  end

  test "generator updates an existing sponsor's tier and badge" do
    file_path = File.join(destination_root, "data/tropicalrb/tropical-on-rails-2026/sponsors.yml")
    run_generator ["--tiers", "Platinum,Gold,Silver", "--event", "tropical-on-rails-2026", "--slug", "typesense", "--tier", "Gold", "--badge", "Wifi Sponsor"]

    run_generator ["--event", "tropical-on-rails-2026", "--slug", "typesense", "--tier", "Platinum"]

    assert_valid_file file_path do |content|
      assert_match(/name: "Platinum"\n\s+level: 0\n\s+sponsors:\n\s+- slug: "?typesense"?\n\s+badge: "?Wifi Sponsor"?/, content)
      assert_equal 1, content.scan("typesense").size
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
