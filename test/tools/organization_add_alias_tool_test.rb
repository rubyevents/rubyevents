require "test_helper"

class OrganizationAddAliasToolTest < ActiveSupport::TestCase
  include StaticOrganizationsSandbox

  setup do
    sandbox_organizations(
      {slug: "appsignal", aliases: [{"name" => "App Signal", "slug" => "app-signal"}], name: "AppSignal", kind: "company", website: "https://www.appsignal.com"},
      {slug: "typesense", name: "Typesense", alternate_names: ["TypeSense"], website: "https://typesense.org"}
    )
  end

  test "adds an alias" do
    result = build_tool.execute(slug: "typesense", alias_slug: "type-sense", alias_name: "Type Sense")

    assert result[:success]
    assert_equal({name: "Type Sense", slug: "type-sense"}, result[:alias_added])
    assert_equal 1, result[:total_aliases]
    assert_match(/validate:fix/, result[:next_step])

    organization = Static::Organization.find_by(slug: "type-sense")
    assert_equal "typesense", organization["slug"]
  end

  test "defaults the alias name to the organization's name" do
    build_tool.execute(slug: "typesense", alias_slug: "typesense-inc")

    assert_includes Static::Organization.find_by(slug: "typesense")["aliases"], {"name" => "Typesense", "slug" => "typesense-inc"}
  end

  test "rejects an alias name the organization already uses" do
    build_tool.execute(slug: "typesense", alias_slug: "typesense-inc")

    assert_match(/Alias name 'Typesense' is already used by typesense/, build_tool.execute(slug: "typesense", alias_slug: "typesense-search")[:error])
    assert build_tool.execute(slug: "typesense", alias_slug: "typesense-search", alias_name: "Typesense Search")[:success]
  end

  test "rejects unknown organizations, existing aliases and slugs of other organizations" do
    assert_match(/not found/, build_tool.execute(slug: "nobody", alias_slug: "x")[:error])
    assert_match(/already exists/, build_tool.execute(slug: "appsignal", alias_slug: "app-signal")[:error])
    assert_match(/belongs to organization 'appsignal'/, build_tool.execute(slug: "typesense", alias_slug: "appsignal")[:error])
  end

  private

  def build_tool
    OrganizationAddAliasTool.new
  end
end
