require "test_helper"

class GeocodeRecordJobTest < ActiveJob::TestCase
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
  end

  teardown do
    Geocoder::Lookup::Test.reset
  end

  test "geocodes user with valid location" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    GeocodeRecordJob.perform_now(user)

    user.reload
    assert_equal "San Francisco", user.city
    assert_equal "CA", user.state_code
    assert_equal "US", user.country_code
    assert_in_delta 37.7749, user.latitude.to_f, 0.01
  end

  test "geocodes event with valid location" do
    series = event_series(:railsconf)
    event = Event.create!(
      name: "Test Conf 2024",
      series: series,
      location: "San Francisco, CA"
    )

    GeocodeRecordJob.perform_now(event)

    event.reload
    assert_equal "San Francisco", event.city
    assert_equal "CA", event.state_code
    assert_equal "US", event.country_code
  end

  test "skips user without location" do
    user = User.create!(name: "Test User", location: nil)

    GeocodeRecordJob.perform_now(user)

    user.reload
    assert_nil user.city
    assert_nil user.latitude
  end

  test "skips user with blank location" do
    user = User.create!(name: "Test User", location: "")

    GeocodeRecordJob.perform_now(user)

    user.reload
    assert_nil user.city
    assert_nil user.latitude
  end

  test "skips event without location" do
    series = event_series(:railsconf)
    event = Event.create!(
      name: "Test Conf 2024",
      series: series,
      location: nil
    )

    GeocodeRecordJob.perform_now(event)

    event.reload
    assert_nil event.city
    assert_nil event.latitude
  end

  test "saves geocoded data to database" do
    user = User.create!(name: "Test User", location: "San Francisco, CA")

    GeocodeRecordJob.perform_now(user)

    fresh_user = User.find(user.id)
    assert_equal "San Francisco", fresh_user.city
    assert_in_delta 37.7749, fresh_user.latitude.to_f, 0.01
  end
end
