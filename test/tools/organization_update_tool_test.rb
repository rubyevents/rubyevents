require "test_helper"

class OrganizationUpdateToolTest < ActiveSupport::TestCase
  include OrganizationToolFile

  test "updates the given fields" do
    result = build_tool.execute(slug: "typesense", website: "https://typesense.org/", main_location: "Houston, TX")

    assert result[:success]
    assert_equal({website: "https://typesense.org/", main_location: "Houston, TX"}, result[:updated_fields])

    organization = Static::Organization.in_file(@tmp_file.path).find_by(slug: "typesense")
    assert_equal "https://typesense.org/", organization["website"]
    assert_equal "Houston, TX", organization["main_location"]
  end

  test "renaming keeps the old name as alternate name" do
    build_tool.execute(slug: "typesense", name: "Typesense Inc")

    organization = Static::Organization.in_file(@tmp_file.path).find_by(slug: "typesense")
    assert_equal "Typesense Inc", organization["name"]
    assert_equal %w[TypeSense Typesense], organization["alternate_names"].sort
  end

  test "changing the slug creates an alias and points to the extract task" do
    result = build_tool.execute(slug: "typesense", new_slug: "typesense-search")

    assert_equal "typesense", result[:alias_created]
    assert_match(/organizations_file:extract/, result[:next_step])

    organization = Static::Organization.in_file(@tmp_file.path).find_by(slug: "typesense-search")
    assert_equal "typesense-search", organization["slug"]
    assert_includes organization["aliases"], {"name" => "Typesense", "slug" => "typesense"}
  end

  test "rejects unknown organizations, taken slugs, empty updates and invalid enums" do
    assert_match(/not found/, build_tool.execute(slug: "nobody", name: "X")[:error])
    assert_match(/already taken/, build_tool.execute(slug: "typesense", new_slug: "app-signal")[:error])
    assert_match(/No fields to update/, build_tool.execute(slug: "typesense")[:error])
    assert_match(/logo_background must be one of/, build_tool.execute(slug: "typesense", logo_background: "pink")[:error])
  end

  private

  def build_tool
    OrganizationUpdateTool.new(organizations_file_path: @tmp_file.path)
  end
end
