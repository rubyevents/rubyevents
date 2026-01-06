require "test_helper"

class User::LocationInfoTest < ActiveSupport::TestCase
  test "country_code returns geocoded country_code when present" do
    user = User.create!(name: "Test User", location: "San Francisco, CA", country_code: "US")

    assert_equal "US", user.location_info.country_code
  end

  test "country_code falls back to parsing location when not geocoded" do
    user = User.create!(name: "Test User", location: "Tokyo, Japan")

    assert_equal "JP", user.location_info.country_code
  end

  test "country returns Country object from geocoded country_code" do
    user = User.create!(name: "Test User", country_code: "US")

    assert_equal "United States of America (the)", user.location_info.country_name
  end

  test "country falls back to parsing location when not geocoded" do
    user = User.create!(name: "Test User", location: "Berlin, Germany")

    assert_equal "Germany", user.location_info.country_name
  end

  test "city returns geocoded city" do
    user = User.create!(name: "Test User", city: "San Francisco")

    assert_equal "San Francisco", user.location_info.city
  end

  test "state returns geocoded state" do
    user = User.create!(name: "Test User", state: "California")

    assert_equal "California", user.location_info.state
  end

  test "latitude returns geocoded latitude" do
    user = User.create!(name: "Test User", latitude: 37.7749)

    assert_equal 37.7749, user.location_info.latitude
  end

  test "longitude returns geocoded longitude" do
    user = User.create!(name: "Test User", longitude: -122.4194)

    assert_equal(-122.4194, user.location_info.longitude)
  end

  test "geocoded? returns true when coordinates present" do
    user = User.create!(name: "Test User", latitude: 37.7749, longitude: -122.4194)

    assert user.location_info.geocoded?
  end

  test "geocoded? returns false when coordinates missing" do
    user = User.create!(name: "Test User")

    assert_not user.location_info.geocoded?
  end

  test "present? returns true when location present" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    assert user.location_info.present?
  end

  test "present? returns false when location blank" do
    user = User.create!(name: "Test User", location: "")

    assert_not user.location_info.present?
  end

  test "to_s returns location string" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    assert_equal "San Francisco, CA", user.location_info.to_s
  end

  test "link_path returns country path when country present" do
    user = User.create!(name: "Test User", country_code: "US")

    assert_equal "/countries/united-states", user.location_info.link_path
  end

  test "link_path returns nil when country not present" do
    user = User.create!(name: "Test User", location: "")

    assert_nil user.location_info.link_path
  end
end
