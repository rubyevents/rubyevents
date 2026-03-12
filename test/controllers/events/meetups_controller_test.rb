require "test_helper"

class Events::MeetupsControllerTest < ActionDispatch::IntegrationTest
  test "should show meetup" do
    active_meetup = events(:wnb_rb_meetup)
    talk = talks(:two)
    talk.update!(date: 2.months.ago, event: active_meetup)

    get meetups_events_url
    assert_response :success
    assert_match active_meetup.name, response.body
  end
end
