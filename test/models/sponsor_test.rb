require "test_helper"

class SponsorTest < ActiveSupport::TestCase
  test "should generate slug from name" do
    sponsor = Sponsor.new(name: "Example Corp")
    sponsor.valid?
    assert_equal "example-corp", sponsor.slug
  end

  test "should validate presence of name" do
    sponsor = Sponsor.new(name: "")
    assert_not sponsor.valid?
    assert_includes sponsor.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    Sponsor.create!(name: "Unique Corp")
    duplicate_sponsor = Sponsor.new(name: "Unique Corp")
    assert_not duplicate_sponsor.valid?
    assert_includes duplicate_sponsor.errors[:name], "has already been taken"
  end

  test "should normalize website with https prefix" do
    sponsor = Sponsor.new(name: "Test Corp", website: "example.com")
    sponsor.save!
    assert_equal "https://example.com", sponsor.website
  end

  test "should preserve https:// prefix in website" do
    sponsor = Sponsor.new(name: "Test Corp", website: "https://example.com")
    sponsor.save!
    assert_equal "https://example.com", sponsor.website
  end

  test "should preserve http:// prefix in website" do
    sponsor = Sponsor.new(name: "Test Corp", website: "http://example.com")
    sponsor.save!
    assert_equal "http://example.com", sponsor.website
  end

  test "should handle blank website" do
    sponsor = Sponsor.new(name: "Test Corp", website: "")
    sponsor.save!
    assert_equal "", sponsor.website
  end

  test "should handle nil website" do
    sponsor = Sponsor.create!(name: "Test Corp", website: nil)
    # Rails normalizes will set the attribute but nil values remain nil if not explicitly converted
    assert_nil sponsor.website
  end

  test "should strip query params from website" do
    sponsor = Sponsor.create!(name: "Query Corp", website: "https://example.com?utm_source=newsletter&ref=123")
    assert_equal "https://example.com", sponsor.website
  end

  test "should strip fragment from website" do
    sponsor = Sponsor.create!(name: "Fragment Corp", website: "https://example.com/path#section")
    assert_equal "https://example.com/path", sponsor.website
  end

  test "should prepend https and strip params if missing scheme" do
    sponsor = Sponsor.create!(name: "Coerce Corp", website: "example.com/?utm_campaign=abc#top")
    assert_equal "https://example.com/", sponsor.website
  end

  test "should default logo_background to white" do
    sponsor = Sponsor.create!(name: "Default Corp")
    assert_equal "white", sponsor.logo_background
  end

  test "should generate correct sponsor_image_path" do
    sponsor = Sponsor.create!(name: "Image Test Corp")
    expected_path = "sponsors/#{sponsor.slug}"
    assert_equal expected_path, sponsor.sponsor_image_path
  end

  test "should generate correct default_sponsor_image_path" do
    sponsor = Sponsor.create!(name: "Default Image Corp")
    assert_equal "sponsors/default", sponsor.default_sponsor_image_path
  end

  test "should generate correct avatar_image_path" do
    sponsor = Sponsor.create!(name: "Avatar Corp")
    expected_path = "sponsors/default/avatar.webp"
    assert_equal expected_path, sponsor.avatar_image_path
  end

  test "should generate correct banner_image_path" do
    sponsor = Sponsor.create!(name: "Banner Corp")
    expected_path = "sponsors/default/banner.webp"
    assert_equal expected_path, sponsor.banner_image_path
  end

  test "should generate correct logo_image_path" do
    sponsor = Sponsor.create!(name: "Logo Corp")
    expected_path = "sponsors/default/logo.webp"
    assert_equal expected_path, sponsor.logo_image_path
  end

  test "should fallback to logo_url when local logo doesn't exist" do
    sponsor = Sponsor.create!(name: "Logo URL Corp", logo_url: "https://example.com/logo.png")
    assert_equal "https://example.com/logo.png", sponsor.logo_image_path
  end

  test "should not add duplicate logo_urls" do
    sponsor = Sponsor.create!(name: "Duplicate Logo Corp")
    sponsor.add_logo_url("https://example.com/logo.png")
    sponsor.add_logo_url("https://example.com/logo.png")

    assert_equal 1, sponsor.logo_urls.count
  end

  test "should not add blank logo_urls" do
    sponsor = Sponsor.create!(name: "Blank Logo Corp")
    sponsor.add_logo_url("")
    sponsor.add_logo_url(nil)

    assert_empty sponsor.logo_urls
  end

  test "should ensure unique logo_urls on save" do
    sponsor = Sponsor.create!(name: "Unique Logo Corp")
    sponsor.logo_urls = ["https://example.com/logo.png", "https://example.com/logo.png", "https://example.com/other.png"]
    sponsor.save!

    assert_equal 2, sponsor.logo_urls.count
    assert_includes sponsor.logo_urls, "https://example.com/logo.png"
    assert_includes sponsor.logo_urls, "https://example.com/other.png"
  end

  test "should preserve https:// prefix in domain" do
    sponsor = Sponsor.create!(name: "Domain Corp", domain: "https://example.com")
    assert_equal "https://example.com", sponsor.domain
  end
end
