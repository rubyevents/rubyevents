require "test_helper"

class MeetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:wnb_rb_meetup)
  end

  test "should get index" do
    get archive_events_url
    assert_response :success
    assert_select "h1", /Events Archive/i
    assert_select "##{dom_id(@event)}", 1
  end
end
