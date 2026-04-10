# frozen_string_literal: true

require "test_helper"

class Static::CityTest < ActiveSupport::TestCase
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

  def reload_city(city)
    City.find_by(id: city.id)
  end

  test "import! creates a new city when none exists" do
    static_city = Static::City.find_by(slug: "zurich")

    assert_difference "City.count", 1 do
      static_city.import!(index: false)
    end

    city = City.find_by(slug: "zurich")
    assert_equal "Zurich", city.name
    assert_equal "CH", city.country_code
    assert city.featured?
  end

  test "import! finds existing city by slug" do
    existing = create_city(name: "Old Zurich Name", country_code: "CH", state_code: "ZH")
    existing.update!(slug: "zurich")

    static_city = Static::City.find_by(slug: "zurich")

    assert_no_difference "City.count" do
      static_city.import!(index: false)
    end

    updated = reload_city(existing)
    assert_equal "Zurich", updated.name
    assert updated.featured?
  end

  test "import! finds existing city by exact name" do
    existing = create_city(name: "Zurich", country_code: "CH", state_code: "ZH")
    existing.update!(slug: "different-slug")

    static_city = Static::City.find_by(slug: "zurich")

    assert_no_difference "City.count" do
      static_city.import!(index: false)
    end

    updated = reload_city(existing)
    assert_equal "zurich", updated.slug
    assert updated.featured?
  end

  test "import! finds existing city when YAML alias matches city name (case-insensitive)" do
    existing = create_city(name: "Zürich", country_code: "CH", state_code: "ZH")
    existing.update!(slug: "zuerich-geocoded")

    static_city = Static::City.find_by(slug: "zurich")

    assert_no_difference "City.count" do
      static_city.import!(index: false)
    end

    updated = reload_city(existing)

    assert_equal "Zurich", updated.name
    assert_equal "zurich", updated.slug
    assert updated.featured?
  end

  test "import! finds existing city when YAML alias matches city name zrh" do
    existing = create_city(name: "ZRH", country_code: "CH", state_code: "ZH")
    existing.update!(slug: "zrh-airport")

    static_city = Static::City.find_by(slug: "zurich")

    assert_no_difference "City.count" do
      static_city.import!(index: false)
    end

    updated = reload_city(existing)
    assert_equal "Zurich", updated.name
    assert updated.featured?
  end

  test "import! finds existing city when YAML alias matches existing database alias" do
    existing = create_city(name: "Zuerich", country_code: "CH", state_code: "ZH")
    existing.update!(slug: "zuerich-old")
    existing.sync_aliases_from_list(["Zürich"])

    static_city = Static::City.find_by(slug: "zurich")

    assert_no_difference "City.count" do
      static_city.import!(index: false)
    end

    updated = reload_city(existing)
    assert_equal "Zurich", updated.name
    assert updated.featured?
  end

  test "import! syncs aliases from YAML" do
    static_city = Static::City.find_by(slug: "zurich")
    static_city.import!(index: false)

    city = City.find_by(slug: "zurich")
    city_aliases = Alias.where(aliasable_type: "City", aliasable_id: city.id).pluck(:name)

    assert_includes city_aliases, "ZRH"
    assert_includes city_aliases, "Zürich"
  end

  test "import! does not create duplicate city for Zürich alias variation" do
    static_city = Static::City.find_by(slug: "zurich")
    static_city.import!(index: false)

    result = City.find_or_create_for(city: "Zürich", country_code: "CH", state_code: "ZH")

    assert_equal 1, City.where(country_code: "CH").where("LOWER(name) LIKE ?", "%zurich%").count
    assert_equal "Zurich", result.name
  end

  test "import! does not create duplicate city for ZRH alias variation" do
    static_city = Static::City.find_by(slug: "zurich")
    static_city.import!(index: false)

    result = City.find_or_create_for(city: "ZRH", country_code: "CH", state_code: "ZH")

    assert_equal 1, City.where(country_code: "CH").where("LOWER(name) LIKE ?", "%zurich%").count
    assert_equal "Zurich", result.name
  end
end
