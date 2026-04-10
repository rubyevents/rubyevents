require "test_helper"

class Spotlight::TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @topic = Topic.approved.canonical.with_talks.first
  end

  test "should get index with turbo stream format" do
    get spotlight_topics_url(format: :turbo_stream)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query" do
    skip "No approved topics with talks" unless @topic
    get spotlight_topics_url(format: :turbo_stream, s: @topic.name)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should limit topics results" do
    get spotlight_topics_url(format: :turbo_stream)
    assert_response :success
    assert assigns(:topics).size <= Spotlight::TopicsController::LIMIT
  end

  test "should not track analytics" do
    assert_no_difference "Ahoy::Event.count" do
      with_event_tracking do
        get spotlight_topics_url(format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
