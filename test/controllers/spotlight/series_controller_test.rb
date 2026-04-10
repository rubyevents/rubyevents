require "test_helper"

class Spotlight::SeriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index with turbo stream format" do
    get spotlight_series_index_url(format: :turbo_stream)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query" do
    get spotlight_series_index_url(format: :turbo_stream, s: "rails")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should not track analytics" do
    assert_no_difference "Ahoy::Event.count" do
      with_event_tracking do
        get spotlight_series_index_url(format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
