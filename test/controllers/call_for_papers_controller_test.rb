require "test_helper"

class CallForPapersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:future_conference)
  end

  test "should get index" do
    get call_for_papers_path
    assert_response :success
    assert_select "h1", /Open Call For Papers/i
  end

  test "should get call4papers link" do
    get call_for_papers_path
    assert_select "link", href: @event.cfp_link
  end

  test "should get call4papers open in future" do
    get call_for_papers_path
    assert_select "div", /CFP opens at/i
  end

  test "should get index call4papers opened" do
    @event.update(cfp_open_date: 1.week.ago, cfp_close_date: 1.day.from_now)

    get call_for_papers_path
    assert_select "div", /CFP closes at/i
  end
end
