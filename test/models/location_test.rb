# frozen_string_literal: true

require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test ".from_record creates location from event fixture" do
    event = events(:future_conference)
    location = Location.from_record(event)

    assert_kind_of Location, location
    assert_nil location.city if event.city.nil?
    assert_nil location.state_code if event.state_code.nil?
    assert_nil location.country_code if event.country_code.nil?
  end

  test ".from_record creates location with full event data" do
    event = OpenStruct.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6,
      location: "Portland, OR, USA"
    )

    location = Location.from_record(event)

    assert_equal "Portland", location.city
    assert_equal "OR", location.state_code
    assert_equal "US", location.country_code
    assert_equal 45.5, location.latitude
    assert_equal(-122.6, location.longitude)
    assert_equal "Portland, OR, USA", location.raw_location
  end

  test ".from_string creates location from raw string" do
    location = Location.from_string("Paris, France")

    assert_equal "Paris, France", location.raw_location
    assert_equal "Paris, France", location.to_s
  end

  test "#geocoded? returns true when lat/lng present" do
    location = Location.new(latitude: 45.5, longitude: -122.6)
    assert location.geocoded?
  end

  test "#geocoded? returns false when lat/lng missing" do
    location = Location.new(city: "Portland")
    refute location.geocoded?
  end

  test "#geocoded? returns false when only latitude present" do
    location = Location.new(latitude: 45.5)
    refute location.geocoded?
  end

  test "#state returns State for US location" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_kind_of State, location.state
    assert_equal "OR", location.state.code
  end

  test "#city_object returns City for US location" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_kind_of City, location.city_object
    assert_equal "portland", location.city_object.slug
  end

  test "#state returns State for GB location" do
    location = Location.new(city: "London", state_code: "ENG", country_code: "GB")

    assert_kind_of State, location.state
    assert_equal "England", location.state.name
  end

  test "#state returns State for AU location" do
    location = Location.new(city: "Sydney", state_code: "NSW", country_code: "AU")

    assert_kind_of State, location.state
    assert_equal "NSW", location.state.code
  end

  test "#state returns State for CA location" do
    location = Location.new(city: "Toronto", state_code: "ON", country_code: "CA")

    assert_kind_of State, location.state
    assert_equal "ON", location.state.code
  end

  test "#state returns nil for country without subdivisions" do
    location = Location.new(city: "Oranjestad", state_code: "XX", country_code: "AW")

    assert_nil location.state
  end

  test "#country returns Country object" do
    location = Location.new(country_code: "US")

    assert_kind_of Country, location.country
    assert_equal "US", location.country.alpha2
  end

  test "#country returns nil without country_code" do
    location = Location.new(city: "Portland")
    assert_nil location.country
  end

  test "#city_path returns path via city_object" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US", latitude: 45.5, longitude: -122.6)

    assert_match %r{/cities/}, location.city_path
  end

  test "#state_path returns path for US state" do
    location = Location.new(state_code: "OR", country_code: "US")

    assert_equal "/states/us/oregon", location.state_path
  end

  test "#state_path returns country path for GB nation" do
    location = Location.new(state_code: "ENG", country_code: "GB")

    assert_equal "/countries/england", location.state_path
  end

  test "#state_path returns nil for country without subdivisions" do
    location = Location.new(state_code: "XX", country_code: "AW")

    assert_nil location.state_path
  end

  test "#country_path returns country path" do
    location = Location.new(country_code: "US")

    assert_equal "/countries/united-states", location.country_path
  end

  test "#state_display_name returns abbreviation for US state by code" do
    location = Location.new(state_code: "OR", country_code: "US")

    assert_equal "OR", location.state_display_name
  end

  test "#state_display_name returns abbreviation for US state by name" do
    location = Location.new(state_code: "Oregon", country_code: "US")

    assert_equal "OR", location.state_display_name
  end

  test "#state_display_name returns full name for GB" do
    location = Location.new(state_code: "ENG", country_code: "GB")

    assert_equal "England", location.state_display_name
  end

  test "#state_display_name returns raw state for country without subdivisions" do
    location = Location.new(state_code: "XX", country_code: "AW")

    assert_equal "XX", location.state_display_name
  end

  test "#display_city includes state for US location" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_equal "Portland, OR", location.display_city
  end

  test "#display_city returns just city for non-state country" do
    location = Location.new(city: "Paris", country_code: "FR")

    assert_equal "Paris", location.display_city
  end

  test "#display_city returns state display name when city equals state display" do
    location = Location.new(city: "OR", state_code: "OR", country_code: "US")

    assert_equal "OR", location.display_city
  end

  test "#display_city includes both when city is state full name" do
    location = Location.new(city: "Oregon", state_code: "OR", country_code: "US")

    assert_equal "Oregon, OR", location.display_city
  end

  test "#has_state? returns true when state_path exists" do
    location = Location.new(state_code: "OR", country_code: "US")

    assert location.has_state?
  end

  test "#has_state? returns false for country without subdivisions" do
    location = Location.new(state_code: "XX", country_code: "AW")

    refute location.has_state?
  end

  test "#has_city? requires both city and country" do
    assert Location.new(city: "Portland", country_code: "US").has_city?
    refute Location.new(city: "Portland").has_city?
    refute Location.new(country_code: "US").has_city?
  end

  test "#present? with city" do
    assert Location.new(city: "Portland").present?
  end

  test "#present? with country_code" do
    assert Location.new(country_code: "US").present?
  end

  test "#present? with raw_location" do
    assert Location.new(raw_location: "Somewhere").present?
  end

  test "#blank? when empty" do
    assert Location.new.blank?
  end

  test "#to_s returns raw_location when present" do
    location = Location.new(raw_location: "Custom Location", city: "Portland", country_code: "US")

    assert_equal "Custom Location", location.to_s
  end

  test "#to_s builds from city and country" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_equal "Portland, OR, United States", location.to_s
  end

  test "#to_s returns just country when no city" do
    location = Location.new(country_code: "US")

    assert_equal "United States", location.to_s
  end

  test "#to_html returns empty string for blank location" do
    location = Location.new

    assert_equal "", location.to_html
  end

  test "#to_html renders raw text for non-geocoded location" do
    location = Location.new(raw_location: "Somewhere")
    html = location.to_html

    assert_includes html, "Somewhere"
    refute_includes html, "<a"
  end

  test "#to_html renders city, state, country with links for US location" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html

    assert_includes html, "Portland"
    assert_includes html, "OR"
    assert_includes html, "United States"
    assert_includes html, "<a"
    assert_includes html, 'class="link"'
    assert_equal 3, html.scan("<a").count
  end

  test "#to_html renders city, country for non-state country" do
    location = Location.new(
      city: "Paris",
      country_code: "FR",
      latitude: 48.8,
      longitude: 2.3
    )
    html = location.to_html

    assert_includes html, "Paris"
    assert_includes html, "France"
    assert_equal 2, html.scan("<a").count
  end

  test "#to_html renders without links when show_links: false" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html(show_links: false)

    refute_includes html, "<a"
    assert_includes html, "Portland"
    assert_includes html, "OR"
    assert_includes html, "United States"
  end

  test "#to_html uses custom link_class" do
    location = Location.new(
      city: "Portland",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html(link_class: "custom-link")

    assert_includes html, 'class="custom-link"'
  end

  test "#to_html renders span for non-geocoded with country" do
    location = Location.new(raw_location: "Paris, France", country_code: "FR")
    html = location.to_html

    assert_includes html, "Paris, France"
    assert_includes html, "<span"
    refute_includes html, "<a"
  end

  test "#to_html renders GB nation correctly" do
    location = Location.new(
      city: "London",
      state_code: "ENG",
      country_code: "GB",
      latitude: 51.5,
      longitude: -0.1
    )
    html = location.to_html

    assert_includes html, "London"
    assert_includes html, "England"
    assert_includes html, "United Kingdom"
  end

  test "#to_html handles AU state" do
    location = Location.new(
      city: "Sydney",
      state_code: "NSW",
      country_code: "AU",
      latitude: -33.8,
      longitude: 151.2
    )
    html = location.to_html

    assert_includes html, "Sydney"
    assert_includes html, "NSW"
    assert_includes html, "Australia"
  end

  test "#to_html handles CA province" do
    location = Location.new(
      city: "Toronto",
      state_code: "ON",
      country_code: "CA",
      latitude: 43.6,
      longitude: -79.3
    )
    html = location.to_html

    assert_includes html, "Toronto"
    assert_includes html, "ON"
    assert_includes html, "Canada"
  end

  test "#to_html renders only country when geocoded but no city" do
    location = Location.new(
      country_code: "US",
      latitude: 40.0,
      longitude: -100.0
    )
    html = location.to_html

    assert_includes html, "United States"
    assert_includes html, "<a"
  end

  test "#to_text returns same as to_s" do
    location = Location.new(city: "Portland", country_code: "US")

    assert_equal location.to_s, location.to_text
  end

  test ".online creates online location" do
    location = Location.online

    assert_equal "online", location.raw_location
    assert location.online?
  end

  test "#to_text returns raw_location when nothing else is present" do
    location = Location.new(raw_location: "Custom Location", city: "", country_code: "")

    assert_equal "Custom Location", location.to_text
  end

  test "#online? returns true for 'Online' location" do
    location = Location.new(raw_location: "online")
    assert location.online?
  end

  test "#online? returns true for 'online' (lowercase)" do
    location = Location.new(raw_location: "online")
    assert location.online?
  end

  test "#online? returns true for 'virtual'" do
    location = Location.new(raw_location: "virtual")
    assert location.online?
  end

  test "#online? returns true for 'remote'" do
    location = Location.new(raw_location: "remote")
    assert location.online?
  end

  test "#online? returns false for geocoded location" do
    location = Location.new(raw_location: "online", latitude: 45.5, longitude: -122.6)
    refute location.online?
  end

  test "#online? returns false for regular location" do
    location = Location.new(raw_location: "Portland, OR")
    refute location.online?
  end

  test "#online_path returns online path" do
    location = Location.online
    assert_equal "/locations/online", location.online_path
  end

  test "#to_html renders online location with link" do
    location = Location.online
    html = location.to_html

    assert_includes html, "online"
    assert_includes html, "<a"
    assert_includes html, "/online"
  end

  test "#to_html renders online location without link when show_links: false" do
    location = Location.online
    html = location.to_html(show_links: false)

    assert_includes html, "online"
    refute_includes html, "<a"
  end

  test "#continent returns Continent instance" do
    location = Location.new(country_code: "US")

    assert_kind_of Continent, location.continent
    assert_equal "North America", location.continent.name
  end

  test "#continent returns nil without country" do
    location = Location.new(city: "Portland")

    assert_nil location.continent
  end

  test "#continent_name returns continent name string" do
    location = Location.new(country_code: "US")

    assert_equal "North America", location.continent_name
  end

  test "#continent_path returns continent path" do
    location = Location.new(country_code: "FR")

    assert_equal "/continents/europe", location.continent_path
  end

  test "#to_html with upto: :city returns just city" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html(upto: :city)

    assert_includes html, "Portland"
    assert_includes html, "OR"
    refute_includes html, "United States"
    assert_equal 1, html.scan("<a").count
  end

  test "#to_html with upto: :state returns city and state" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html(upto: :state)

    assert_includes html, "Portland"
    assert_includes html, "OR"
    refute_includes html, "United States"
    assert_equal 2, html.scan("<a").count
  end

  test "#to_html with upto: :continent includes continent" do
    location = Location.new(
      city: "Paris",
      country_code: "FR",
      latitude: 48.8,
      longitude: 2.3
    )
    html = location.to_html(upto: :continent)

    assert_includes html, "Paris"
    assert_includes html, "France"
    assert_includes html, "Europe"
    assert_equal 3, html.scan("<a").count
  end

  test "#to_html with upto: :continent for US location" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html(upto: :continent)

    assert_includes html, "Portland"
    assert_includes html, "OR"
    assert_includes html, "United States"
    assert_includes html, "North America"
    assert_equal 4, html.scan("<a").count
  end

  test "#to_html with upto: :city for non-state country" do
    location = Location.new(
      city: "Paris",
      country_code: "FR",
      latitude: 48.8,
      longitude: 2.3
    )
    html = location.to_html(upto: :city)

    assert_includes html, "Paris"
    refute_includes html, "France"
    assert_equal 1, html.scan("<a").count
  end

  test "#to_html with upto: and show_links: false" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6
    )
    html = location.to_html(upto: :continent, show_links: false)

    assert_includes html, "Portland"
    assert_includes html, "OR"
    assert_includes html, "United States"
    assert_includes html, "North America"
    refute_includes html, "<a"
  end

  test "#to_text returns plain text for location" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_equal "Portland, OR, United States", location.to_text
  end

  test "#to_text with upto: :city" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_equal "Portland, OR", location.to_text(upto: :city)
  end

  test "#to_text with upto: :state" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_equal "Portland, OR", location.to_text(upto: :state)
  end

  test "#to_text with upto: :continent" do
    location = Location.new(city: "Portland", state_code: "OR", country_code: "US")

    assert_equal "Portland, OR, United States, North America", location.to_text(upto: :continent)
  end

  test "#to_text for non-state country" do
    location = Location.new(city: "Paris", country_code: "FR")

    assert_equal "Paris, France", location.to_text
    assert_equal "Paris", location.to_text(upto: :city)
    assert_equal "Paris, France, Europe", location.to_text(upto: :continent)
  end

  test "#to_text returns Online for online location" do
    location = Location.online

    assert_equal "online", location.to_text
  end

  test "#to_text returns empty string for blank location" do
    location = Location.new

    assert_equal "", location.to_text
  end

  test "#hybrid? returns true when hybrid is true" do
    location = Location.new(city: "Tokyo", country_code: "JP", hybrid: true)

    assert location.hybrid?
  end

  test "#hybrid? returns false when hybrid is false" do
    location = Location.new(city: "Tokyo", country_code: "JP", hybrid: false)

    refute location.hybrid?
  end

  test "#hybrid? returns false by default" do
    location = Location.new(city: "Tokyo", country_code: "JP")

    refute location.hybrid?
  end

  test "#to_html appends & online for hybrid locations" do
    location = Location.new(
      city: "Tokyo",
      country_code: "JP",
      latitude: 35.6,
      longitude: 139.7,
      hybrid: true
    )
    html = location.to_html

    assert_includes html, "Tokyo"
    assert_includes html, "Japan"
    assert_includes html, "& "
    assert_includes html, "online"
    assert_includes html, "/online"
  end

  test "#to_html renders hybrid without online link when show_links: false" do
    location = Location.new(
      city: "Tokyo",
      country_code: "JP",
      latitude: 35.6,
      longitude: 139.7,
      hybrid: true
    )
    html = location.to_html(show_links: false)

    assert_includes html, "Tokyo"
    assert_includes html, "Japan"
    assert_includes html, "& "
    assert_includes html, "online"
    assert_includes html, "<span"
  end

  test "#to_text appends & online for hybrid locations" do
    location = Location.new(
      city: "Tokyo",
      country_code: "JP",
      hybrid: true
    )

    assert_equal "Tokyo, Japan & online", location.to_text
  end

  test "#to_text with upto: option still appends & online for hybrid" do
    location = Location.new(
      city: "Tokyo",
      country_code: "JP",
      hybrid: true
    )

    assert_equal "Tokyo & online", location.to_text(upto: :city)
    assert_equal "Tokyo, Japan & online", location.to_text(upto: :country)
    assert_equal "Tokyo, Japan, Asia & online", location.to_text(upto: :continent)
  end

  test "hybrid does not affect online-only locations" do
    location = Location.online

    refute location.hybrid?
    assert_equal "online", location.to_text
  end

  test "#to_text appends & online for hybrid US location with state" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      hybrid: true
    )

    assert_equal "Portland, OR, United States & online", location.to_text
  end

  test "#to_text appends & online for hybrid GB location" do
    location = Location.new(
      city: "London",
      state_code: "ENG",
      country_code: "GB",
      hybrid: true
    )

    assert_equal "London, England, United Kingdom & online", location.to_text
  end

  test "#to_text appends & online for hybrid country-only location" do
    location = Location.new(
      country_code: "JP",
      hybrid: true
    )

    assert_equal "Japan & online", location.to_text
  end

  test "#to_html appends & online for hybrid US location" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6,
      hybrid: true
    )
    html = location.to_html

    assert_includes html, "Portland"
    assert_includes html, "OR"
    assert_includes html, "United States"
    assert_includes html, "& "
    assert_includes html, "online"
    assert_includes html, "/online"
  end

  test "#to_html with upto: :city for hybrid location" do
    location = Location.new(
      city: "Portland",
      state_code: "OR",
      country_code: "US",
      latitude: 45.5,
      longitude: -122.6,
      hybrid: true
    )
    html = location.to_html(upto: :city)

    assert_includes html, "Portland"
    assert_includes html, "OR"
    refute_includes html, "United States"
    assert_includes html, "& "
    assert_includes html, "online"
  end

  test "#to_html with upto: :continent for hybrid location" do
    location = Location.new(
      city: "Paris",
      country_code: "FR",
      latitude: 48.8,
      longitude: 2.3,
      hybrid: true
    )
    html = location.to_html(upto: :continent)

    assert_includes html, "Paris"
    assert_includes html, "France"
    assert_includes html, "Europe"
    assert_includes html, "& "
    assert_includes html, "online"
  end

  test "hybrid with raw_location fallback" do
    location = Location.new(
      raw_location: "Custom Venue, City",
      hybrid: true
    )

    assert_equal "Custom Venue, City & online", location.to_text
  end

  test "hybrid with non-geocoded raw_location renders as span" do
    location = Location.new(
      raw_location: "Conference Center",
      hybrid: true
    )
    html = location.to_html

    assert_includes html, "Conference Center"
    assert_includes html, "<span"
  end

  test "hybrid with geocoded country renders country and online" do
    location = Location.new(
      country_code: "JP",
      latitude: 35.6,
      longitude: 139.7,
      hybrid: true
    )
    html = location.to_html

    assert_includes html, "Japan"
    assert_includes html, "& "
    assert_includes html, "online"
  end

  test "#from_record preserves hybrid from static_metadata" do
    event = OpenStruct.new(
      city: "Tokyo",
      state_code: nil,
      country_code: "JP",
      latitude: 35.6,
      longitude: 139.7,
      location: "Tokyo, Japan",
      static_metadata: OpenStruct.new(hybrid?: true)
    )

    location = Location.from_record(event)

    assert location.hybrid?
    assert_equal "Tokyo, Japan & online", location.to_text
  end

  test "#from_record defaults hybrid to false when no static_metadata" do
    event = OpenStruct.new(
      city: "Tokyo",
      state_code: nil,
      country_code: "JP",
      latitude: 35.6,
      longitude: 139.7,
      location: "Tokyo, Japan"
    )

    location = Location.from_record(event)

    refute location.hybrid?
    assert_equal "Tokyo, Japan", location.to_text
  end
end
