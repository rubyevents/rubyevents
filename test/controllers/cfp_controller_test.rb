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
    assert_select "div", /CFP opens on/i
  end

  test "should get index call4papers opened" do
    @event.cfps.first.update(open_date: 1.week.ago, close_date: 1.day.from_now)

    get cfp_index_path
    assert_select "div", /CFP closes on/i
  end
end
