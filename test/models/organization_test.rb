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
    # Rails normalizes will set the attribute but nil values remain nil if not explicitly converted
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
end
