require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:future_conference)
    @user = users(:lazaro_nixon)
  end

  test "should get index" do
    get events_url
    assert_response :success
    assert_select "h1", /Upcoming Events/i
    assert_select "[data-event-id=#{@event.slug}]", 2
  end

  test "should get index as ics" do
    get events_url(format: :ics)
    assert_response :success
    assert_equal "text/calendar; charset=utf-8", response.content_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "UID:RUBYEVENTS-#{@event.id}"
  end

  test "should show event" do
    get event_url(@event)
    assert_response :success
  end

  test "should show event talks" do
    get event_talks_url(@event)
    assert_response :success
  end

  test "should show event events" do
    get event_events_url(@event)
    assert_response :success
  end

  test "should redirect to canonical event" do
    @talk = talks(:one)
    @talk.update(event: @event)
    canonical_event = events(:rubyconfth_2022)
    @event.assign_canonical_event!(canonical_event: canonical_event)
    get event_url(@event)

    assert_redirected_to event_url(canonical_event)
  end

  test "should redirect to root for wrong slugs" do
    get event_url("wrong-slug")
    assert_response :moved_permanently
    assert_redirected_to root_path
  end

  test "should redirect to correct event slug when accessed via alias" do
    @event.slug_aliases.create!(name: "Old Name", slug: "old-event-slug")

    get event_url("old-event-slug")
    assert_response :moved_permanently
    assert_redirected_to event_path(@event)
  end

  test "should display an empty state message when no events are found" do
    Event.destroy_all

    get archive_events_url

    assert_response :success
    assert_select "p", text: "No events found"
  end
end
