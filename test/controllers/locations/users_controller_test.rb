# frozen_string_literal: true

require "test_helper"

class Locations::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a user with US location and coordinates
    @us_user = User.create!(
      name: "US Ruby Developer",
      email: "us_dev@example.com",
      slug: "us-ruby-developer",
      location: "San Francisco, CA",
      city: "San Francisco",
      state_code: "CA",
      country_code: "US",
      latitude: 37.7749,
      longitude: -122.4194
    )
    cities(:san_francisco)
  end

  # Country Tests
  test "should get users index for country and display user" do
    get country_users_path("united-states")
    assert_response :success
    assert_select "body", text: /#{@us_user.name}/
  end

  test "should handle invalid country gracefully" do
    get country_users_path("nonexistent-country")
    assert_redirected_to countries_path
  end

  # City Tests
  test "should get users index for city" do
    get city_users_path("san-francisco")
    assert_response :success
    assert_select "body", text: /#{@us_user.name}/
  end

  # State Tests
  test "should get users index for state" do
    get state_users_path("us", "california")
    assert_response :success
    assert_select "body", text: /#{@us_user.name}/
  end

  test "should handle invalid state gracefully" do
    get state_users_path("us", "nonexistent-state")
    assert_redirected_to country_path("united-states")
  end

  # Continent Tests
  test "should get users index for continent" do
    get continent_users_path("north-america")
    assert_response :success
    assert_select "body", text: /#{@us_user.name}/
  end

  test "should handle invalid continent gracefully" do
    get continent_users_path("nonexistent-continent")
    assert_redirected_to continents_path
  end

  # Coordinate Location Tests
  test "should get users index for coordinates" do
    get coordinates_users_path("38.0639,-122.8397")
    assert_response :success
    assert_select "body", text: /#{@us_user.name}/
  end
end
