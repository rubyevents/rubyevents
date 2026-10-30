require "test_helper"

class OrganizationCreateToolTest < ActiveSupport::TestCase
  include StaticOrganizationsSandbox

  setup do
    sandbox_organizations(
      {slug: "appsignal", aliases: [{"name" => "App Signal", "slug" => "app-signal"}], name: "AppSignal", kind: "company", website: "https://www.appsignal.com"},
      {slug: "typesense", name: "Typesense", alternate_names: ["TypeSense"], website: "https://typesense.org"}
    )
  end

  test "adds an organization with a derived slug" do
    result = build_tool.execute(name: "Planet Argon", website: "https://www.planetargon.com", kind: "company")

    assert result[:success]
    assert_equal "planet-argon", result[:slug]

    organization = Static::Organization.find_by(slug: "planet-argon")
    assert_equal "Planet Argon", organization["name"]
    assert_equal "https://www.planetargon.com", organization["website"]
    assert_equal "company", organization["kind"]
  end

  test "rejects duplicates and unknown kinds" do
    assert_match(/already exists/, build_tool.execute(name: "AppSignal")[:error])
    assert_match(/slug 'app-signal' already exists/, build_tool.execute(name: "App Signal Inc", slug: "app-signal")[:error])
    assert_match(/kind must be one of/, build_tool.execute(name: "New Org", kind: "club")[:error])
  end

  private

  def build_tool
    OrganizationCreateTool.new
  end
end
