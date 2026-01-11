require "test_helper"

class GeocodeableTest < ActiveSupport::TestCase
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
      "Berlin, Germany", [
        {
          "coordinates" => [52.52, 13.405],
          "address" => "Berlin, Germany",
          "city" => "Berlin",
          "state" => "Berlin",
          "state_code" => "BE",
          "postal_code" => "10115",
          "country" => "Germany",
          "country_code" => "DE"
        }
      ]
    )

    Geocoder::Lookup::Test.add_stub(
      "Unknown Location XYZ123", []
    )
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end

  test "geocodeable? returns true when location is present" do
    user = User.new(name: "Test", location: "San Francisco, CA")
    assert user.geocodeable?
  end

  test "geocodeable? returns false when location is blank" do
    user = User.new(name: "Test", location: "")
    assert_not user.geocodeable?
  end

  test "geocodeable? returns false when location is nil" do
    user = User.new(name: "Test", location: nil)
    assert_not user.geocodeable?
  end

  test "clear_geocode clears all geocode data" do
    user = User.create!(
      name: "Test User",
      location: "San Francisco, CA",
      latitude: 37.7749,
      longitude: -122.4194,
      city: "San Francisco",
      state_code: "CA",
      country_code: "US",
      geocode_metadata: {"foo" => "bar"}
    )

    user.clear_geocode

    assert_nil user.latitude
    assert_nil user.longitude
    assert_nil user.city
    assert_nil user.state_code
    assert_nil user.country_code
    assert_equal({}, user.geocode_metadata)
  end

  test "regeocode clears existing data and geocodes fresh" do
    user = User.create!(
      name: "Test User",
      location: "Berlin, Germany",
      latitude: 37.7749,
      longitude: -122.4194,
      city: "San Francisco",
      state_code: "CA",
      country_code: "US"
    )

    user.regeocode

    assert_equal "Berlin", user.city
    assert_equal "BE", user.state_code
    assert_equal "DE", user.country_code
    assert_in_delta 52.52, user.latitude.to_f, 0.01
    assert_in_delta 13.405, user.longitude.to_f, 0.01
  end

  test "regeocode works when no previous geocode data exists" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    user.regeocode

    assert_equal "San Francisco", user.city
    assert_equal "CA", user.state_code
    assert_equal "US", user.country_code
  end

  test "geocode does not overwrite existing latitude" do
    user = User.create!(
      name: "Test User",
      location: "San Francisco, CA",
      latitude: 99.999
    )

    user.geocode

    assert_in_delta 99.999, user.latitude.to_f, 0.001
  end

  test "geocode does not overwrite existing longitude" do
    user = User.create!(
      name: "Test User",
      location: "San Francisco, CA",
      longitude: -99.999
    )

    user.geocode

    assert_in_delta(-99.999, user.longitude.to_f, 0.001)
  end

  test "geocode fills in missing latitude when longitude is present" do
    user = User.create!(
      name: "Test User",
      location: "San Francisco, CA",
      longitude: -122.4194
    )

    user.geocode

    assert_in_delta 37.7749, user.latitude.to_f, 0.01
    assert_in_delta(-122.4194, user.longitude.to_f, 0.01)
  end

  test "with_coordinates scope returns records with both lat and long" do
    with_coords = User.create!(name: "With", latitude: 37.7749, longitude: -122.4194)
    without_coords = User.create!(name: "Without")
    partial = User.create!(name: "Partial", latitude: 37.7749)

    assert_includes User.with_coordinates, with_coords
    assert_not_includes User.with_coordinates, without_coords
    assert_not_includes User.with_coordinates, partial
  end

  test "without_coordinates scope returns records missing lat or long" do
    with_coords = User.create!(name: "With", latitude: 37.7749, longitude: -122.4194)
    without_coords = User.create!(name: "Without")
    partial = User.create!(name: "Partial", latitude: 37.7749)

    assert_not_includes User.without_coordinates, with_coords
    assert_includes User.without_coordinates, without_coords
    assert_includes User.without_coordinates, partial
  end

  test "geocode stores metadata with timestamp" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    freeze_time do
      user.geocode
      user.save!

      assert user.geocode_metadata["geocoded_at"].present?
      assert_equal Time.current.iso8601, user.geocode_metadata["geocoded_at"]
    end
  end
end
