require "test_helper"

class CountryTest < ActiveSupport::TestCase
  test "find_by returns country for valid country code" do
    country = Country.find_by(country_code: "US")

    assert_not_nil country
    assert_equal "US", country.alpha2
    assert_equal "United States of America (the)", country.iso_short_name
  end

  test "find_by returns country for lowercase country code" do
    country = Country.find_by(country_code: "de")

    assert_not_nil country
    assert_equal "DE", country.alpha2
  end

  test "find_by returns nil for invalid code" do
    country = Country.find_by(country_code: "XX")

    assert_nil country
  end

  test "find returns country by name" do
    country = Country.find("Germany")

    assert_not_nil country
    assert_equal "DE", country.alpha2
  end

  test "find returns country by unofficial name" do
    country = Country.find("USA")

    assert_not_nil country
    assert_equal "US", country.alpha2
  end

  test "find returns nil for empty string" do
    assert_nil Country.find("")
  end

  test "find returns nil for online" do
    assert_nil Country.find("online")
    assert_nil Country.find("Online")
  end

  test "find returns nil for earth" do
    assert_nil Country.find("earth")
    assert_nil Country.find("Earth")
  end

  test "find returns nil for unknown" do
    assert_nil Country.find("unknown")
    assert_nil Country.find("Unknown")
  end

  test "find returns US for US state abbreviations" do
    country = Country.find("CA")

    assert_not_nil country
    assert_equal "US", country.alpha2
  end

  test "find returns GB for UK" do
    country = Country.find("UK")

    assert_not_nil country
    assert_equal "GB", country.alpha2
  end

  test "find returns GB for Scotland" do
    country = Country.find("Scotland")

    assert_not_nil country
    assert_equal "GB", country.alpha2
  end

  test "find handles hyphenated terms" do
    country = Country.find("united-states")

    assert_not_nil country
    assert_equal "US", country.alpha2
  end

  test "all returns hash of countries by slug" do
    countries = Country.all

    assert countries.is_a?(Hash)
    assert countries.key?("germany")
    assert countries.key?("united-states-of-america-the")
  end

  test "slugs returns array of country slugs" do
    slugs = Country.slugs

    assert slugs.is_a?(Array)
    assert_includes slugs, "germany"
  end
end
