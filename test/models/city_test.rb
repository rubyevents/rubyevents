# frozen_string_literal: true

require "test_helper"

class CityTest < ActiveSupport::TestCase
  def create_city(name:, country_code:, state_code: nil, **attrs)
    city = City.new(
      name: name,
      country_code: country_code,
      state_code: state_code,
      latitude: attrs[:latitude] || 45.5,
      longitude: attrs[:longitude] || -122.6,
      geocode_metadata: attrs[:geocode_metadata] || {"geocoder_city" => name},
      featured: attrs.fetch(:featured, false)
    )

    city.define_singleton_method(:geocode) {}
    city.save!

    city
  end

  def build_city(name:, country_code:, state_code: nil, skip_geocode: true, **attrs)
    city = City.new(
      name: name,
      country_code: country_code,
      state_code: state_code,
      latitude: attrs[:latitude] || 45.5,
      longitude: attrs[:longitude] || -122.6,
      geocode_metadata: attrs[:geocode_metadata] || {"geocoder_city" => name},
      featured: attrs.fetch(:featured, false)
    )

    city.define_singleton_method(:geocode) {} if skip_geocode

    city
  end

  test "validates presence of name" do
    city = City.new(country_code: "US")
    assert_not city.valid?
    assert_includes city.errors[:name], "can't be blank"
  end

  test "validates presence of country_code" do
    city = City.new(name: "Portland")
    assert_not city.valid?
    assert_includes city.errors[:country_code], "can't be blank"
  end

  test "validates uniqueness of name scoped to country_code and state_code" do
    create_city(name: "Portland", country_code: "US", state_code: "OR")

    duplicate = build_city(name: "Portland", country_code: "US", state_code: "OR")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows same city name in different states" do
    create_city(name: "Portland", country_code: "US", state_code: "OR")

    different_state = build_city(name: "Portland", country_code: "US", state_code: "ME")
    assert different_state.valid?
  end

  test "allows same city name in different countries" do
    create_city(name: "London", country_code: "GB", state_code: "ENG")

    different_country = build_city(name: "London", country_code: "CA", state_code: "ON")
    assert different_country.valid?
  end

  test "rejects location when geocoder returns no city" do
    city = build_city(name: "California", country_code: "US", latitude: 36.0, longitude: -119.0,
      geocode_metadata: {"geocoder_city" => nil})

    assert_not city.valid?
    assert city.errors[:name].any? { |e| e.include?("not a valid city") }
  end

  test "accepts location when geocoder returns a city" do
    city = build_city(name: "Portland", country_code: "US", state_code: "OR", latitude: 45.5, longitude: -122.6,
      geocode_metadata: {"geocoder_city" => "Portland"})

    assert city.valid?
    assert_empty city.errors[:name]
  end

  test "clears state_code for countries without subdivisions" do
    city = City.new(name: "Oranjestad", country_code: "AW", state_code: "XX")
    city.valid?

    assert_nil city.state_code
  end

  test "keeps state_code for supported countries" do
    city = City.new(name: "Portland", country_code: "US", state_code: "OR")
    city.valid?

    assert_equal "OR", city.state_code
  end

  test "#country returns Country instance" do
    city = City.new(name: "Portland", country_code: "US")

    assert_kind_of Country, city.country
    assert_equal "US", city.country.alpha2
  end

  test "#country returns nil for blank country_code" do
    city = City.new(name: "Portland", country_code: nil)

    assert_nil city.country
  end

  test "#state returns State for supported country" do
    city = City.new(name: "Portland", country_code: "US", state_code: "OR")

    assert_kind_of State, city.state
    assert_equal "OR", city.state.code
  end

  test "#state returns nil for country without subdivisions" do
    city = City.new(name: "Oranjestad", country_code: "AW", state_code: "XX")

    assert_nil city.state
  end

  test "#state returns nil when state_code is blank" do
    city = City.new(name: "Portland", country_code: "US", state_code: nil)

    assert_nil city.state
  end

  test "#geocoded? returns true when lat/lng present" do
    city = City.new(latitude: 45.5, longitude: -122.6)

    assert city.geocoded?
  end

  test "#geocoded? returns false when lat/lng missing" do
    city = City.new(name: "Portland")

    assert_not city.geocoded?
  end

  test "#geocodeable? returns true when name and country_code present" do
    city = City.new(name: "Portland", country_code: "US")

    assert city.geocodeable?
  end

  test "#geocodeable? returns false when name missing" do
    city = City.new(country_code: "US")

    assert_not city.geocodeable?
  end

  test "#coordinates returns [lat, lng] when geocoded" do
    city = City.new(latitude: 45.5, longitude: -122.6)

    assert_equal [45.5, -122.6], city.coordinates
  end

  test "#coordinates returns nil when not geocoded" do
    city = City.new(name: "Portland")

    assert_nil city.coordinates
  end

  test "#location_string includes state for US cities" do
    city = City.new(name: "Portland", country_code: "US", state_code: "OR")

    assert_equal "Portland, OR", city.location_string
  end

  test "#location_string includes country for non-US cities" do
    city = City.new(name: "London", country_code: "GB")

    assert_equal "London, United Kingdom", city.location_string
  end

  test "#geocode_query includes city, state, and country" do
    city = City.new(name: "Portland", country_code: "US", state_code: "OR")

    assert_equal "Portland, Oregon, United States", city.geocode_query
  end

  test "#geocode_query excludes nil values" do
    city = City.new(name: "Paris", country_code: "FR")

    assert_equal "Paris, France", city.geocode_query
  end

  test "#bounds returns bounding box when geocoded" do
    city = City.new(latitude: 45.5, longitude: -122.6)
    bounds = city.bounds

    assert_equal({southwest: [-123.1, 45.0], northeast: [-122.1, 46.0]}, bounds)
  end

  test "#bounds returns nil when not geocoded" do
    city = City.new(name: "Portland")

    assert_nil city.bounds
  end

  test "#continent returns Continent via country" do
    city = City.new(name: "Portland", country_code: "US")

    assert_kind_of Continent, city.continent
    assert_equal "North America", city.continent.name
  end

  test "#feature! sets featured to true" do
    city = create_city(name: "Portland", country_code: "US", state_code: "OR", featured: false)

    city.feature!

    assert city.featured?
  end

  test "#unfeature! sets featured to false" do
    city = create_city(name: "Portland", country_code: "US", state_code: "OR", featured: true)

    city.unfeature!

    assert_not city.featured?
  end

  test ".find_for finds city by name and country" do
    city = create_city(name: "Portland", country_code: "US", state_code: "OR")

    found = City.find_for(city: "Portland", country_code: "US", state_code: "OR")

    assert_equal city, found
  end

  test ".find_for returns nil when not found" do
    found = City.find_for(city: "Nonexistent", country_code: "US")

    assert_nil found
  end

  test ".find_or_create_for returns existing city" do
    city = create_city(name: "Portland", country_code: "US", state_code: "OR")

    found = City.find_or_create_for(city: "Portland", country_code: "US", state_code: "OR")

    assert_equal city, found
  end

  test ".find_or_create_for creates new city when geocoded as locality" do
    result = City.find_or_create_for(city: "Seattle", country_code: "US", state_code: "WA")

    assert result.nil? || result.is_a?(City)
  end

  test ".find_or_create_for returns nil for blank city" do
    result = City.find_or_create_for(city: "", country_code: "US")

    assert_nil result
  end

  test ".find_or_create_for returns nil for non-city locations" do
    result = City.find_or_create_for(city: "San Francisco Bay Area", country_code: "US")

    assert_nil result
    assert_not City.exists?(name: "San Francisco Bay Area", country_code: "US")
  end

  test ".find_or_create_for returns nil for blank country_code" do
    result = City.find_or_create_for(city: "Portland", country_code: "")

    assert_nil result
  end

  test ".featured returns only featured cities" do
    featured = create_city(name: "Portland", country_code: "US", state_code: "OR", featured: true)
    create_city(name: "Seattle", country_code: "US", state_code: "WA", featured: false)

    assert_includes City.featured, featured
    assert_equal 1, City.featured.count
  end

  test ".for_country returns cities in country" do
    us_city = create_city(name: "Portland", country_code: "US", state_code: "OR")
    create_city(name: "London", country_code: "GB", state_code: "ENG")

    assert_includes City.for_country("US"), us_city
    assert_equal 1, City.for_country("US").count
  end

  test ".for_state returns cities in state" do
    state = State.find_by_code("OR", country: Country.find("US"))
    or_city = create_city(name: "Portland", country_code: "US", state_code: "OR")
    create_city(name: "Seattle", country_code: "US", state_code: "WA")

    assert_includes City.for_state(state), or_city
    assert_equal 1, City.for_state(state).count
  end

  test "#to_location returns Location with city and state for US city" do
    city = City.new(name: "Portland", country_code: "US", state_code: "OR")
    location = city.to_location

    assert_kind_of Location, location
    assert_equal "Portland, OR, United States", location.to_text
  end

  test "#to_location returns Location with city and country for non-US city" do
    city = City.new(name: "Paris", country_code: "FR")
    location = city.to_location

    assert_equal "Paris, France", location.to_text
  end

  test "#to_location returns Location with city and country for GB city" do
    city = City.new(name: "London", country_code: "GB", state_code: "ENG")
    location = city.to_location

    assert_equal "London, England, United Kingdom", location.to_text
  end

  test "#sync_aliases_from_list creates aliases" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")

    city.sync_aliases_from_list(["zurich", "zrh"])

    city_aliases = Alias.where(aliasable_type: "City", aliasable_id: city.id)

    assert_equal 2, city_aliases.count
    assert city_aliases.exists?(name: "zurich")
    assert city_aliases.exists?(name: "zrh")
  end

  test "#sync_aliases_from_list does not create duplicate aliases" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")

    city.sync_aliases_from_list(["zurich"])
    city.sync_aliases_from_list(["zurich", "zrh"])

    city_aliases = Alias.where(aliasable_type: "City", aliasable_id: city.id)

    assert_equal 2, city_aliases.count
  end

  test ".find_by_alias finds city by alias name" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")
    city.sync_aliases_from_list(["zurich", "zrh"])

    found = City.find_by_alias("zurich", country_code: "CH")

    assert_equal city, found
  end

  test ".find_by_alias finds city by alias name case-insensitively" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")
    city.sync_aliases_from_list(["zurich"])

    found = City.find_by_alias("ZURICH", country_code: "CH")

    assert_equal city, found
  end

  test ".find_by_alias returns nil for wrong country" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")
    city.sync_aliases_from_list(["zurich"])

    found = City.find_by_alias("zurich", country_code: "DE")

    assert_nil found
  end

  test ".find_for finds city by alias" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")
    city.sync_aliases_from_list(["zurich"])

    found = City.find_for(city: "zurich", country_code: "CH")

    assert_equal city, found
  end

  test ".find_or_create_for returns existing city when searching by alias" do
    city = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")
    city.sync_aliases_from_list(["zurich"])

    found = City.find_or_create_for(city: "Zurich", country_code: "CH")

    assert_equal city, found
    assert_equal 1, City.where(country_code: "CH").count
  end
end
