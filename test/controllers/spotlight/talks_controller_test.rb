require "test_helper"

class Spotlight::TalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @talk = talks(:one)
    @event = events(:rails_world_2023)
    @talk.update(event: @event)
  end

  test "should get index with turbo stream format" do
    get spotlight_talks_url(format: :turbo_stream)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query" do
    get spotlight_talks_url(format: :turbo_stream, s: @talk.title)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should filter out unbalanced quotes" do
    get spotlight_talks_url(format: :turbo_stream, s: 'Hotwire"')
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should filter out invalid quotes" do
    get spotlight_talks_url(format: :turbo_stream, s: "'")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should filter out invalid search characters" do
    get spotlight_talks_url(format: :turbo_stream, s: "Hotwire\nCookbook")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should limit results to 5 talks" do
    6.times do |i|
      Talk.create!(
        title: "Talk #{i}",
        event: @event,
        date: Time.current,
        static_id: "test-spotlight-talk-#{i}"
      )
    end

    get spotlight_talks_url(format: :turbo_stream)
    assert_response :success
    assert_equal 5, assigns(:talks).size
    assert_equal Talk.watchable.count, assigns(:talks_count)
  end

  test "should not track analytics" do
    assert_no_difference "Ahoy::Event.count" do
      with_event_tracking do
        get spotlight_talks_url(format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
