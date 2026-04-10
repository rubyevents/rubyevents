require "test_helper"

class Spotlight::LocationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index with turbo stream format" do
    get spotlight_locations_url(format: :turbo_stream)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query for country" do
    event = events(:rails_world_2023)
    event.update(country_code: "US")

    get spotlight_locations_url(format: :turbo_stream, s: "united")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query for city" do
    event = events(:rails_world_2023)
    event.update(city: "Amsterdam", country_code: "NL")

    get spotlight_locations_url(format: :turbo_stream, s: "amsterdam")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should not track analytics" do
    assert_no_difference "Ahoy::Event.count" do
      with_event_tracking do
        get spotlight_locations_url(format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
