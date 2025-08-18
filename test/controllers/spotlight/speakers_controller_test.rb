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

  test "should limit results to 5 speakers" do
    6.times { |i| User.create!(name: "Speaker #{i}", talks_count: 1, email: "speaker#{i}@rubyevents.org", password: "password") }

    get spotlight_speakers_url(format: :turbo_stream)
    assert_response :success
    assert_equal 5, assigns(:speakers).size
    assert assigns(:speakers_count).positive?
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
