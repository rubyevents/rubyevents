require "test_helper"
require "ostruct"

class EventGeocodingTest < ActiveSupport::TestCase
  setup do
    Geocoder::Lookup::Test.add_stub(
      "San Francisco, CA", [
        {
          "coordinates" => [37.7749, -122.4194],
          "address" => "San Francisco, CA, USA",
          "city" => "San Francisco",
          "state" => "California",
          "state_code" => "CA",
          "postal_code" => "94102",
          "country" => "United States",
          "country_code" => "US"
        }
      ]
    )

    Geocoder::Lookup::Test.add_stub(
      "Chicago, IL", [
        {
          "coordinates" => [41.8781, -87.6298],
          "address" => "Chicago, IL, USA",
          "city" => "Chicago",
          "state" => "Illinois",
          "state_code" => "IL",
          "postal_code" => "60601",
          "country" => "United States",
          "country_code" => "US"
        }
      ]
    )

    Geocoder::Lookup::Test.add_stub(
      "San Francisco, California, United States", [
        {
          "coordinates" => [37.7749, -122.4194],
          "city" => "San Francisco",
          "state_code" => "CA",
          "country_code" => "US"
        }
      ]
    )

    Geocoder::Lookup::Test.add_stub(
      "Chicago, Illinois, United States", [
        {
          "coordinates" => [41.8781, -87.6298],
          "city" => "Chicago",
          "state_code" => "IL",
          "country_code" => "US"
        }
      ]
    )

    @series = event_series(:railsconf)
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end

  test "geocode with valid location" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA"
    )

    event.geocode
    event.save!

    assert_equal "San Francisco", event.city
    assert_equal "CA", event.state_code
    assert_equal "US", event.country_code
    assert_in_delta 37.7749, event.latitude.to_f, 0.01
    assert_in_delta(-122.4194, event.longitude.to_f, 0.01)
  end

  test "geocode stores metadata" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA"
    )

    event.geocode
    event.save!

    assert event.geocode_metadata.present?
    assert event.geocode_metadata["geocoded_at"].present?
  end

  test "event geocodeable? returns true when location present" do
    event = Event.new(name: "Test", series: @series, location: "San Francisco, CA")
    assert event.geocodeable?
  end

  test "event geocodeable? returns false when location blank" do
    event = Event.new(name: "Test", series: @series, location: "")
    assert_not event.geocodeable?
  end

  test "event clear_geocode clears all geocode data" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA",
      latitude: 37.7749,
      longitude: -122.4194,
      city: "San Francisco",
      state_code: "CA",
      country_code: "US",
      geocode_metadata: {"foo" => "bar"}
    )

    event.clear_geocode

    assert_nil event.latitude
    assert_nil event.longitude
    assert_nil event.city
    assert_nil event.state_code
    assert_nil event.country_code
    assert_equal({}, event.geocode_metadata)
  end

  test "event regeocode clears and geocodes fresh" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "Chicago, IL",
      latitude: 37.7749,
      longitude: -122.4194,
      city: "San Francisco",
      state_code: "CA",
      country_code: "US"
    )

    event.regeocode

    assert_equal "Chicago", event.city
    assert_equal "IL", event.state_code
    assert_equal "US", event.country_code
    assert_in_delta 41.8781, event.latitude.to_f, 0.01
    assert_in_delta(-87.6298, event.longitude.to_f, 0.01)
  end

  test "with_coordinates scope works for events" do
    with_coords = Event.create!(
      name: "With Coords",
      series: @series,
      latitude: 37.7749,
      longitude: -122.4194
    )

    without_coords = Event.create!(
      name: "Without Coords",
      series: @series
    )

    assert_includes Event.with_coordinates, with_coords
    assert_not_includes Event.with_coordinates, without_coords
  end

  test "without_coordinates scope works for events" do
    with_coords = Event.create!(
      name: "With Coords",
      series: @series,
      latitude: 37.7749,
      longitude: -122.4194
    )

    without_coords = Event.create!(
      name: "Without Coords",
      series: @series
    )

    assert_not_includes Event.without_coordinates, with_coords
    assert_includes Event.without_coordinates, without_coords
  end

  test "geocode uses venue coordinates when venue exists" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA"
    )

    venue_stub = OpenStruct.new(
      exist?: true,
      coordinates: {"latitude" => 40.7128, "longitude" => -74.0060}
    )

    event.define_singleton_method(:venue) { venue_stub }

    event.geocode

    assert_in_delta 40.7128, event.latitude.to_f, 0.01
    assert_in_delta(-74.0060, event.longitude.to_f, 0.01)

    assert_equal "San Francisco", event.city
    assert_equal "CA", event.state_code
    assert_equal "US", event.country_code
  end

  test "geocode uses geocoder coordinates when venue has no coordinates" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA"
    )

    venue_stub = OpenStruct.new(exist?: true, coordinates: {})
    event.define_singleton_method(:venue) { venue_stub }

    event.geocode

    assert_in_delta 37.7749, event.latitude.to_f, 0.01
    assert_in_delta(-122.4194, event.longitude.to_f, 0.01)
  end

  test "geocode uses geocoder coordinates when venue does not exist" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA"
    )

    venue_stub = OpenStruct.new(exist?: false)
    event.define_singleton_method(:venue) { venue_stub }

    event.geocode

    assert_in_delta 37.7749, event.latitude.to_f, 0.01
    assert_in_delta(-122.4194, event.longitude.to_f, 0.01)
  end

  test "geocode preserves venue coordinates on regeocode" do
    event = Event.create!(
      name: "Test Conf 2024",
      series: @series,
      location: "San Francisco, CA",
      latitude: 99.0,
      longitude: -99.0
    )

    venue_stub = OpenStruct.new(
      exist?: true,
      coordinates: {"latitude" => 40.7128, "longitude" => -74.0060}
    )

    event.define_singleton_method(:venue) { venue_stub }

    event.regeocode

    assert_in_delta 40.7128, event.latitude.to_f, 0.01
    assert_in_delta(-74.0060, event.longitude.to_f, 0.01)
  end
end
