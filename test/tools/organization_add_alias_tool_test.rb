require "test_helper"

class OrganizationAddAliasToolTest < ActiveSupport::TestCase
  include OrganizationToolFile

  test "adds an alias" do
    result = build_tool.execute(slug: "typesense", alias_slug: "type-sense", alias_name: "Type Sense")

    assert result[:success]
    assert_equal({name: "Type Sense", slug: "type-sense"}, result[:alias_added])
    assert_equal 1, result[:total_aliases]
    assert_match(/organizations_file:extract/, result[:next_step])

    organization = Static::Organization.in_file(@tmp_file.path).find_by(slug: "type-sense")
    assert_equal "typesense", organization["slug"]
  end

  test "defaults the alias name to the organization's name" do
    build_tool.execute(slug: "typesense", alias_slug: "typesense-inc")

    assert_includes Static::Organization.in_file(@tmp_file.path).find_by(slug: "typesense")["aliases"], {"name" => "Typesense", "slug" => "typesense-inc"}
  end

  test "rejects unknown organizations, existing aliases and slugs of other organizations" do
    assert_match(/not found/, build_tool.execute(slug: "nobody", alias_slug: "x")[:error])
    assert_match(/already exists/, build_tool.execute(slug: "appsignal", alias_slug: "app-signal")[:error])
    assert_match(/belongs to organization 'appsignal'/, build_tool.execute(slug: "typesense", alias_slug: "appsignal")[:error])
  end

  private

  def build_tool
    OrganizationAddAliasTool.new(organizations_file_path: @tmp_file.path)
  end
end
