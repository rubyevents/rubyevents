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
end
