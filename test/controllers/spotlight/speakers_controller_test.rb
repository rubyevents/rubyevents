require "test_helper"

class Spotlight::SpeakersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @speaker = users(:marco)
  end

  test "should get index with turbo stream format" do
    get spotlight_speakers_url(format: :turbo_stream)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query" do
    get spotlight_speakers_url(format: :turbo_stream, s: @speaker.name)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_equal @speaker.id, assigns(:speakers).first.id
  end

  test "should limit speakers results" do
    16.times { |i| User.create!(name: "Speaker #{i}", talks_count: 1, email: "speaker#{i}@rubyevents.org", password: "password") }

    get spotlight_speakers_url(format: :turbo_stream)
    assert_response :success
    assert_equal 15, assigns(:speakers).size
  end

  test "should filter out unbalanced quotes" do
    get spotlight_speakers_url(format: :turbo_stream, s: 'marco"')
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should filter out invalid quotes" do
    get spotlight_speakers_url(format: :turbo_stream, s: "'")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should filter out invalid quotes with single quotes" do
    get spotlight_speakers_url(format: :turbo_stream, s: "marco'")
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should not track analytics" do
    assert_no_difference "Ahoy::Event.count" do
      with_event_tracking do
        get spotlight_speakers_url(format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
