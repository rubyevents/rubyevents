# frozen_string_literal: true

require "test_helper"

class ContinentTest < ActiveSupport::TestCase
  test "find returns Continent for valid slug" do
    continent = Continent.find("europe")

    assert_not_nil continent
    assert_equal "Europe", continent.name
  end

  test "find returns nil for invalid slug" do
    assert_nil Continent.find("invalid")
  end

  test "find returns nil for blank" do
    assert_nil Continent.find(nil)
    assert_nil Continent.find("")
  end

  test "find_by_name returns Continent for valid name" do
    continent = Continent.find_by_name("Europe")

    assert_not_nil continent
    assert_equal "europe", continent.slug
  end

  test "all returns array of Continent instances" do
    continents = Continent.all

    assert continents.is_a?(Array)
    assert_equal 7, continents.size
    assert continents.first.is_a?(Continent)
  end

  test "slugs returns array of continent slugs" do
    slugs = Continent.slugs

    assert_includes slugs, "europe"
    assert_includes slugs, "north-america"
    assert_includes slugs, "asia"
  end

  test "name returns continent name" do
    continent = Continent.find("europe")

    assert_equal "Europe", continent.name
  end

  test "alpha2 returns continent code" do
    continent = Continent.find("europe")

    assert_equal "EU", continent.alpha2
  end

  test "emoji_flag returns continent emoji" do
    continent = Continent.find("europe")

    assert_equal continent.emoji_flag, continent.emoji_flag
  end

  test "path returns continents path with slug" do
    continent = Continent.find("europe")

    assert_equal "/continents/europe", continent.path
  end

  test "to_param returns slug" do
    continent = Continent.find("europe")

    assert_equal "europe", continent.to_param
  end

  test "bounds returns bounding box" do
    continent = Continent.find("europe")
    bounds = continent.bounds

    assert bounds.is_a?(Hash)
    assert bounds.key?(:southwest)
    assert bounds.key?(:northeast)
  end

  test "countries returns array of Country instances" do
    continent = Continent.find("europe")
    countries = continent.countries

    assert countries.is_a?(Array)
    assert countries.any?
    assert countries.first.is_a?(Country)
  end

  test "country_codes returns alpha2 codes for countries" do
    continent = Continent.find("europe")
    codes = continent.country_codes

    assert_includes codes, "DE"
    assert_includes codes, "FR"
    assert_includes codes, "GB"
  end

  test "two continents with same slug are equal" do
    continent1 = Continent.find("europe")
    continent2 = Continent.find("europe")

    assert_equal continent1, continent2
  end

  test "two continents with different slugs are not equal" do
    continent1 = Continent.find("europe")
    continent2 = Continent.find("asia")

    assert_not_equal continent1, continent2
  end

  test "to_location returns Location with continent name" do
    continent = Continent.find("europe")
    location = continent.to_location

    assert_kind_of Location, location
    assert_equal "Europe", location.to_text
  end

  test "to_location for North America" do
    continent = Continent.find("north-america")
    location = continent.to_location

    assert_equal "North America", location.to_text
  end

  test "to_location for all continents returns name" do
    Continent.all.each do |continent|
      location = continent.to_location

      assert_equal continent.name, location.to_text, "Expected to_location.to_text for #{continent.slug} to return #{continent.name}"
    end
  end
end
