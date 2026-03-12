require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "should generate slug from name" do
    organization = Organization.new(name: "Example Corp")
    organization.valid?
    assert_equal "example-corp", organization.slug
  end

  test "should validate presence of name" do
    organization = Organization.new(name: "")
    assert_not organization.valid?
    assert_includes organization.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    Organization.create!(name: "Unique Corp")
    duplicate_organization = Organization.new(name: "Unique Corp")
    assert_not duplicate_organization.valid?
    assert_includes duplicate_organization.errors[:name], "has already been taken"
  end

  test "should normalize website with https prefix" do
    organization = Organization.new(name: "Test Corp", website: "example.com")
    organization.save!
    assert_equal "https://example.com", organization.website
  end

  test "should preserve https:// prefix in website" do
    organization = Organization.new(name: "Test Corp", website: "https://example.com")
    organization.save!
    assert_equal "https://example.com", organization.website
  end

  test "should preserve http:// prefix in website" do
    organization = Organization.new(name: "Test Corp", website: "http://example.com")
    organization.save!
    assert_equal "http://example.com", organization.website
  end

  test "should handle blank website" do
    organization = Organization.new(name: "Test Corp", website: "")
    organization.save!
    assert_equal "", organization.website
  end

  test "should handle nil website" do
    organization = Organization.create!(name: "Test Corp", website: nil)
    assert_nil organization.website
  end

  test "should strip query params from website" do
    organization = Organization.create!(name: "Query Corp", website: "https://example.com?utm_source=newsletter&ref=123")
    assert_equal "https://example.com", organization.website
  end

  test "should strip fragment from website" do
    organization = Organization.create!(name: "Fragment Corp", website: "https://example.com/path#section")
    assert_equal "https://example.com/path", organization.website
  end

  test "should prepend https and strip params if missing scheme" do
    organization = Organization.create!(name: "Coerce Corp", website: "example.com/?utm_campaign=abc#top")
    assert_equal "https://example.com/", organization.website
  end

  test "should default to unknown kind" do
    organization = Organization.create!(name: "Default Corp")
    assert_equal "unknown", organization.kind
  end

  test "should allow setting kind to community" do
    organization = Organization.create!(name: "Community Group", kind: :community)
    assert_equal "community", organization.kind
  end

  test "should allow setting kind to foundation" do
    organization = Organization.create!(name: "Test Foundation", kind: :foundation)
    assert_equal "foundation", organization.kind
  end

  test "should allow setting kind to non_profit" do
    organization = Organization.create!(name: "Test Nonprofit", kind: :non_profit)
    assert_equal "non_profit", organization.kind
  end

  test "should default logo_background to white" do
    organization = Organization.create!(name: "Logo Background Corp")
    assert_equal "white", organization.logo_background
  end

  test "should generate correct organization_image_path" do
    organization = Organization.create!(name: "Image Test Corp")
    expected_path = "organizations/#{organization.slug}"
    assert_equal expected_path, organization.organization_image_path
  end

  test "should generate correct default_organization_image_path" do
    organization = Organization.create!(name: "Default Image Corp")
    assert_equal "organizations/default", organization.default_organization_image_path
  end

  test "should generate correct avatar_image_path" do
    organization = Organization.create!(name: "Avatar Corp")
    expected_path = "organizations/default/avatar.webp"
    assert_equal expected_path, organization.avatar_image_path
  end

  test "should generate correct banner_image_path" do
    organization = Organization.create!(name: "Banner Corp")
    expected_path = "organizations/default/banner.webp"
    assert_equal expected_path, organization.banner_image_path
  end

  test "should generate correct logo_image_path" do
    organization = Organization.create!(name: "Logo Corp")
    expected_path = "organizations/default/logo.webp"
    assert_equal expected_path, organization.logo_image_path
  end

  test "should fallback to logo_url when local logo doesn't exist" do
    organization = Organization.create!(name: "Logo URL Corp", logo_url: "https://example.com/logo.png")
    assert_equal "https://example.com/logo.png", organization.logo_image_path
  end

  test "should not add duplicate logo_urls" do
    organization = Organization.create!(name: "Duplicate Logo Corp")
    organization.add_logo_url("https://example.com/logo.png")
    organization.add_logo_url("https://example.com/logo.png")

    assert_equal 1, organization.logo_urls.count
  end

  test "should not add blank logo_urls" do
    organization = Organization.create!(name: "Blank Logo Corp")
    organization.add_logo_url("")
    organization.add_logo_url(nil)

    assert_empty organization.logo_urls
  end

  test "should ensure unique logo_urls on save" do
    organization = Organization.create!(name: "Unique Logo Corp")
    organization.logo_urls = ["https://example.com/logo.png", "https://example.com/logo.png", "https://example.com/other.png"]
    organization.save!

    assert_equal 2, organization.logo_urls.count
    assert_includes organization.logo_urls, "https://example.com/logo.png"
    assert_includes organization.logo_urls, "https://example.com/other.png"
  end

  test "find_by_name_or_alias finds organization by name" do
    organization = Organization.create!(name: "Name Test Corp")

    found_organization = Organization.find_by_name_or_alias("Name Test Corp")
    assert_equal organization.id, found_organization.id
  end

  test "find_by_name_or_alias finds organization by alias name" do
    organization = Organization.create!(name: "Current Corp Name")
    organization.aliases.create!(name: "Old Corp Name", slug: "old-corp-name")

    found_organization = Organization.find_by_name_or_alias("Old Corp Name")
    assert_equal organization.id, found_organization.id
  end

  test "find_by_name_or_alias returns nil for non-existent name" do
    found_organization = Organization.find_by_name_or_alias("Nonexistent Corp")
    assert_nil found_organization
  end

  test "find_by_name_or_alias returns nil for blank name" do
    assert_nil Organization.find_by_name_or_alias("")
    assert_nil Organization.find_by_name_or_alias(nil)
  end

  test "find_by_name_or_alias prioritizes name over alias" do
    org1 = Organization.create!(name: "Real Corp")
    org2 = Organization.create!(name: "Other Corp")
    org2.aliases.create!(name: "Real Corp Alias", slug: "real-corp")

    found_organization = Organization.find_by_name_or_alias("Real Corp")
    assert_equal org1.id, found_organization.id
  end

  test "find_by_slug_or_alias finds organization by slug" do
    organization = Organization.create!(name: "Slug Test Corp")

    found_organization = Organization.find_by_slug_or_alias(organization.slug)
    assert_equal organization.id, found_organization.id
  end

  test "find_by_slug_or_alias finds organization by alias slug" do
    organization = Organization.create!(name: "Primary Corp")
    organization.aliases.create!(name: "Old Corp Name", slug: "old-corp")

    found_organization = Organization.find_by_slug_or_alias("old-corp")
    assert_equal organization.id, found_organization.id
  end

  test "find_by_slug_or_alias returns nil for non-existent slug" do
    found_organization = Organization.find_by_slug_or_alias("nonexistent-slug")
    assert_nil found_organization
  end

  test "find_by_slug_or_alias returns nil for blank slug" do
    assert_nil Organization.find_by_slug_or_alias("")
    assert_nil Organization.find_by_slug_or_alias(nil)
  end

  test "find_by_slug_or_alias prioritizes slug over alias" do
    org1 = Organization.create!(name: "Organization One")
    org2 = Organization.create!(name: "Organization Two")
    org2.aliases.create!(name: "Alias", slug: org1.slug)

    found_organization = Organization.find_by_slug_or_alias(org1.slug)
    assert_equal org1.id, found_organization.id
  end
end
