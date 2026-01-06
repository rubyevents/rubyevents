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
    assert_nil Country.find_by(country_code: "XX")
  end

  test "find_by returns nil for blank code" do
    assert_nil Country.find_by(country_code: nil)
    assert_nil Country.find_by(country_code: "")
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

  test "find returns nil for nil" do
    assert_nil Country.find(nil)
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

  test "all returns array of Country instances" do
    countries = Country.all

    assert countries.is_a?(Array)
    assert countries.first.is_a?(Country)
  end

  test "all_by_slug returns hash of countries by slug" do
    countries = Country.all_by_slug

    assert countries.is_a?(Hash)
    assert countries.key?("germany")
    assert countries["germany"].is_a?(Country)
  end

  test "slugs returns array of country slugs" do
    slugs = Country.slugs

    assert slugs.is_a?(Array)
    assert_includes slugs, "germany"
  end

  test "name returns English translation" do
    country = Country.find_by(country_code: "DE")

    assert_equal "Germany", country.name
  end

  test "name returns United States for US" do
    country = Country.find_by(country_code: "US")

    assert_equal "United States", country.name
  end

  test "slug returns parameterized name" do
    country = Country.find_by(country_code: "DE")

    assert_equal "germany", country.slug
  end

  test "slug handles multi-word names" do
    country = Country.find_by(country_code: "US")

    assert_equal "united-states", country.slug
  end

  test "path returns countries path with slug" do
    country = Country.find_by(country_code: "DE")

    assert_equal "/countries/germany", country.path
  end

  test "code returns lowercase alpha2" do
    country = Country.find_by(country_code: "DE")

    assert_equal "de", country.code
  end

  test "to_param returns slug for use in Rails path helpers" do
    country = Country.find_by(country_code: "DE")

    assert_equal "germany", country.to_param
  end

  test "two countries with same alpha2 are equal" do
    country1 = Country.find_by(country_code: "DE")
    country2 = Country.find_by(country_code: "DE")

    assert_equal country1, country2
  end

  test "two countries with different alpha2 are not equal" do
    country1 = Country.find_by(country_code: "DE")
    country2 = Country.find_by(country_code: "US")

    assert_not_equal country1, country2
  end

  test "country is not equal to non-Country objects" do
    country = Country.find_by(country_code: "DE")

    assert_not_equal country, "DE"
    assert_not_equal country, nil
  end

  test "eql? returns true for countries with same alpha2" do
    country1 = Country.find_by(country_code: "DE")
    country2 = Country.find_by(country_code: "DE")

    assert country1.eql?(country2)
  end

  test "hash is same for countries with same alpha2" do
    country1 = Country.find_by(country_code: "DE")
    country2 = Country.find_by(country_code: "DE")

    assert_equal country1.hash, country2.hash
  end

  test "countries can be used as hash keys" do
    country1 = Country.find_by(country_code: "DE")
    country2 = Country.find_by(country_code: "DE")

    hash = {country1 => "value"}

    assert_equal "value", hash[country2]
  end

  test "record returns underlying ISO3166::Country" do
    country = Country.find_by(country_code: "DE")

    assert country.record.is_a?(ISO3166::Country)
    assert_equal "DE", country.record.alpha2
  end

  test "delegates alpha2 to record" do
    country = Country.find_by(country_code: "DE")

    assert_equal "DE", country.alpha2
  end

  test "delegates continent to record" do
    country = Country.find_by(country_code: "DE")

    assert_equal "Europe", country.continent
  end

  test "delegates emoji_flag to record" do
    country = Country.find_by(country_code: "DE")

    assert_equal "🇩🇪", country.emoji_flag
  end

  test "select_options returns array of [name, alpha2] pairs" do
    options = Country.select_options

    assert options.is_a?(Array)
    assert options.first.is_a?(Array)
    assert_equal 2, options.first.size

    names = options.map(&:first)
    assert_equal names.sort, names
  end

  test "select_options contains expected countries" do
    options = Country.select_options
    option_map = options.to_h

    assert_equal "DE", option_map["Germany"]
    assert_equal "US", option_map["United States"]
  end

  test "events returns ActiveRecord::Relation" do
    country = Country.find_by(country_code: "NL")

    assert country.events.is_a?(ActiveRecord::Relation)
  end

  test "events returns events matching country_code" do
    country = Country.find_by(country_code: "NL")
    event = events(:rails_world_2023)
    event.update!(country_code: "NL")

    assert_includes country.events, event
  end

  test "events does not include events from other countries" do
    country = Country.find_by(country_code: "NL")
    event = events(:rails_world_2023)
    event.update!(country_code: "DE")

    assert_not_includes country.events, event
  end

  test "users returns ActiveRecord::Relation" do
    country = Country.find_by(country_code: "US")

    assert country.users.is_a?(ActiveRecord::Relation)
  end

  test "users returns users matching country_code" do
    country = Country.find_by(country_code: "US")
    user = User.create!(name: "Test User", country_code: "US")

    assert_includes country.users, user
  end

  test "users does not include users from other countries" do
    country = Country.find_by(country_code: "US")
    user = User.create!(name: "Test User", country_code: "DE")

    assert_not_includes country.users, user
  end

  test "stamps returns array of stamps for the country" do
    country = Country.find_by(country_code: "NL")

    assert country.stamps.is_a?(Array)
  end

  test "stamps returns stamps matching country" do
    country = Country.find_by(country_code: "NL")
    stamps = country.stamps

    stamps.each do |stamp|
      assert stamp.has_country?
      assert_equal "NL", stamp.country.alpha2
    end
  end

  test "held_in_sentence returns sentence for regular country" do
    country = Country.find_by(country_code: "DE")

    assert_equal " held in Germany", country.held_in_sentence
  end

  test "held_in_sentence returns sentence with 'the' for United countries" do
    country = Country.find_by(country_code: "US")

    assert_equal " held in the United States", country.held_in_sentence
  end

  test "held_in_sentence returns sentence with 'the' for United Kingdom" do
    country = Country.find_by(country_code: "GB")

    assert_equal " held in the United Kingdom", country.held_in_sentence
  end
end
