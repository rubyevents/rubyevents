require "test_helper"

class Events::PastControllerTest < ActionDispatch::IntegrationTest
  test "should get index with the globe" do
    event = events(:rails_world_2023)
    event.update!(start_date: 1.month.ago, end_date: 1.month.ago, date: 1.month.ago, latitude: 52.37, longitude: 4.9)

    get past_events_url

    assert_response :success
    assert_select "[data-event-id=#{event.slug}]", 2
    assert_select "#events-globe[data-globe-markers-value*=?]", event.slug
  end
end
