require "test_helper"

class CFPControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:future_conference)
  end

  test "should get index" do
    get cfp_index_path
    assert_response :success
    assert_select "h1", /Open Call for Proposals/i
  end

  test "should get call4papers link" do
    get cfp_index_path
    assert_select "link", href: @event.cfps.first.link
  end

  test "should get call4papers open in future" do
    get cfp_index_path
    assert_select "div", /opens on/i
  end

  test "should get index call4papers opened" do
    @event.cfps.first.update(open_date: 1.week.ago, close_date: 1.day.from_now)

    get cfp_index_path
    assert_select "div", /closes on/i
  end

  test "should show subscribe to calendar button" do
    get cfp_index_path
    assert_select "button", /Subscribe to calendar/i
  end

  test "should get index as ics" do
    @event.cfps.first.update(open_date: 1.week.ago, close_date: 1.week.from_now)

    get cfp_index_url(format: :ics)
    assert_response :success
    assert_equal "text/calendar; charset=utf-8", response.content_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "RUBYEVENTS-CFP-#{@event.cfps.first.id}"
  end
end
