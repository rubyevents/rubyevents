require "test_helper"

class Events::MeetupsControllerTest < ActionDispatch::IntegrationTest
  test "should show meetup" do
    active_meetup = events(:wnb_rb_meetup)
    events(:new_rb_meetup).destroy

    get meetups_events_url
    assert_response :success
    assert_match active_meetup.name, response.body
    assert_select "#events-globe a[data-event-list-target=caption][data-event-id=?]", active_meetup.slug
  end
end
