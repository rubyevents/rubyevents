require "test_helper"

class Spotlight::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @series = event_series(:railsconf)
    @event = events(:railsconf_2017)
  end

  test "should get index with turbo stream format" do
    get spotlight_events_url(format: :turbo_stream)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get index with search query" do
    get spotlight_events_url(format: :turbo_stream, s: @event.name)
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_equal @event.id, assigns(:events).first.id
  end

  test "should limit events results" do
    20.times { |i| Event.create!(name: "Event #{i}", series: @series) }

    get spotlight_events_url(format: :turbo_stream)
    assert_response :success
    assert_equal 15, assigns(:events).size
  end

  test "should not track analytics" do
    assert_no_difference "Ahoy::Event.count" do
      with_event_tracking do
        get spotlight_events_url(format: :turbo_stream)
        assert_response :success
      end
    end
  end
end
