require "test_helper"

class UserGeocodingTest < ActiveSupport::TestCase
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
      "Berlin, Berlin, Germany", [
        {
          "coordinates" => [52.52, 13.405],
          "city" => "Berlin",
          "state_code" => "BE",
          "country_code" => "DE"
        }
      ]
    )
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end

  test "geocode with valid location" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    user.geocode
    user.save!

    assert_equal "San Francisco", user.city
    assert_equal "CA", user.state_code
    assert_equal "US", user.country_code
    assert_in_delta 37.7749, user.latitude.to_f, 0.01
    assert_in_delta(-122.4194, user.longitude.to_f, 0.01)
    assert user.geocode_metadata.present?
    assert user.geocode_metadata["geocoded_at"].present?
  end

  test "geocode with blank location does nothing" do
    user = User.create!(name: "Test User", location: "")

    user.geocode

    assert_nil user.city
    assert_nil user.state_code
    assert_nil user.country_code
    assert_nil user.latitude
    assert_nil user.longitude
  end

  test "geocode with nil location does nothing" do
    user = User.create!(name: "Test User", location: nil)

    user.geocode

    assert_nil user.city
    assert_nil user.latitude
  end

  test "geocode with no results does nothing" do
    user = User.create!(name: "Test User", location: "Unknown Location XYZ123")

    user.geocode

    assert_nil user.city
    assert_nil user.latitude
  end

  test "geocoded? returns true when coordinates present" do
    user = User.create!(name: "Test User", latitude: 37.7749, longitude: -122.4194)

    assert user.geocoded?
  end

  test "geocoded? returns false when coordinates missing" do
    user = User.create!(name: "Test User")

    assert_not user.geocoded?
  end

  test "geocoded? returns false when only latitude present" do
    user = User.create!(name: "Test User", latitude: 37.7749)

    assert_not user.geocoded?
  end

  test "geocoded scope returns geocoded users" do
    geocoded_user = User.create!(name: "Geocoded", latitude: 37.7749, longitude: -122.4194)
    not_geocoded_user = User.create!(name: "Not Geocoded")

    assert_includes User.geocoded, geocoded_user
    assert_not_includes User.geocoded, not_geocoded_user
  end

  test "not_geocoded scope returns users without coordinates" do
    geocoded_user = User.create!(name: "Geocoded", latitude: 37.7749, longitude: -122.4194)
    not_geocoded_user = User.create!(name: "Not Geocoded")

    assert_includes User.not_geocoded, not_geocoded_user
    assert_not_includes User.not_geocoded, geocoded_user
  end

  test "geocode stores raw result data in metadata" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    user.geocode
    user.save!

    assert user.geocode_metadata["geocoded_at"].present?
    assert_equal "San Francisco, CA, USA", user.geocode_metadata["address"]
    assert_equal "United States", user.geocode_metadata["country"]
    assert_equal [37.7749, -122.4194], user.geocode_metadata["coordinates"]
  end

  test "geocode with different location" do
    user = User.create!(name: "Test User", location: "Berlin, Germany")

    user.geocode
    user.save!

    assert_equal "Berlin", user.city
    assert_equal "BE", user.state_code
    assert_equal "DE", user.country_code
    assert_in_delta 52.52, user.latitude.to_f, 0.01
    assert_in_delta 13.405, user.longitude.to_f, 0.01
  end
end
