require "test_helper"
require "generators/organization/organization_generator"

class OrganizationGeneratorTest < Rails::Generators::TestCase
  include StaticOrganizationsSandbox

  tests OrganizationGenerator

  setup do
    self.class.destination Dir.mktmpdir("organization_generator", Rails.root.join("tmp").to_s)
    sandbox_organizations({slug: "typesense", name: "Typesense", website: "https://typesense.org"})
  end

  teardown { FileUtils.remove_entry(destination_root) }

  test "adds an organization with a slug derived from the name" do
    run_generator ["--name", "Planet Argon", "--website", "https://www.planetargon.com", "--logo-url", "https://www.planetargon.com/logo.png", "--kind", "company"]

    organization = Static::Organization.find_by(slug: "planet-argon")
    assert_equal "Planet Argon", organization.name
    assert_equal "https://www.planetargon.com", organization.website
    assert_equal "https://www.planetargon.com/logo.png", organization.logo_url
    assert_equal "company", organization.kind
    assert_valid_file
  end

  test "updates only the given fields of an existing organization" do
    run_generator ["--slug", "typesense", "--main-location", "Houston, TX", "--alternate-names", "TypeSense", "typesense"]

    organization = Static::Organization.find_by(slug: "typesense")
    assert_equal "Typesense", organization.name
    assert_equal "https://typesense.org", organization.website
    assert_equal "Houston, TX", organization.main_location
    assert_equal %w[TypeSense typesense], organization["alternate_names"]
    assert_valid_file
  end

  test "adds an alias for a merged duplicate" do
    run_generator ["--slug", "typesense", "--alias-slug", "type-sense", "--alias-name", "Type Sense"]

    organization = Static::Organization.find_by(slug: "type-sense")
    assert_equal "typesense", organization.slug
    assert_equal [{"name" => "Type Sense", "slug" => "type-sense"}], organization["aliases"]
    assert_valid_file
  end

  test "fails for an unknown slug without a name" do
    error = capture(:stderr) { run_generator ["--slug", "nobody"] }

    assert_match(/No organization with slug 'nobody'/, error)
    assert_nil Static::Organization.find_by(slug: "nobody")
  end

  private

  def assert_valid_file
    errors = Static::Validators::Validator.organization_validator_classes.flat_map do |validator|
      validator.new(file_path: Static::Organization.file_path).errors
    end

    assert_empty errors, errors.map(&:message).join(", ")
  end
end
