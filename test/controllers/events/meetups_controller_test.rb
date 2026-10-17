require "test_helper"

class Events::MeetupsControllerTest < ActionDispatch::IntegrationTest
  test "should show meetup" do
    active_meetup = events(:wnb_rb_meetup)
    events(:new_rb_meetup).destroy

    get meetups_events_url
    assert_response :success
    assert_match active_meetup.name, response.body
  end

  test "should mark meetups of an ended series as inactive" do
    series = EventSeries.create!(name: "Triangle.rb", slug: "triangle-rb", kind: :meetup)
    Event.create!(name: "Triangle.rb Meetup", kind: :meetup, series: series)

    get meetups_events_url
    assert_response :success
    assert_match "Triangle.rb Meetup", response.body
    assert_match "Inactive", response.body
  end
end
