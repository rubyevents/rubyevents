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

  test "should get index call4papers info" do
    get call_for_papers_path
    assert_select "div", /CFP closes at/i
    assert_select "link", href: @event.cfp_link
  end
end
