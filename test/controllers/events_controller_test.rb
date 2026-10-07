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

  test "should render a pill for every continent except Antarctica" do
    get events_url

    assert_response :success
    assert_select "nav[aria-label=?] a", "Filter events by continent", count: Continent.populated.size + 1
    assert_select "nav[aria-label=?] a", "Filter events by continent", text: "Antarctica", count: 0
    assert_select "nav[aria-label=?] a[aria-current=page]", "Filter events by continent", text: "All"
  end

  test "should filter upcoming events by continent" do
    europe, north_america = upcoming_events_on_two_continents

    get events_url
    assert_response :success
    assert_select "[data-event-id=#{europe.slug}]"
    assert_select "[data-event-id=#{north_america.slug}]"

    get events_url(continent: "europe")
    assert_response :success
    assert_select "[data-event-id=#{europe.slug}]"
    assert_select "[data-event-id=#{north_america.slug}]", false
    assert_select "nav[aria-label=?] a[aria-current=page]", "Filter events by continent", text: "Europe"
  end

  test "should ignore an unknown continent" do
    get events_url(continent: "not-a-continent")

    assert_response :success
    assert_select "[data-event-id=#{@event.slug}]", 2
    assert_select "nav[aria-label=?] a[aria-current=page]", "Filter events by continent", text: "All"
  end

  test "should show the empty state for a continent without events" do
    get events_url(continent: "africa")

    assert_response :success
    assert_select "h2", text: "No events found"
    assert_select "[data-event-id=#{@event.slug}]", false
  end

  test "should filter the ics feed by continent" do
    europe, north_america = upcoming_events_on_two_continents

    get events_url(format: :ics, continent: "europe")

    assert_response :success
    assert_includes response.body, "UID:RUBYEVENTS-#{europe.id}"
    assert_not_includes response.body, "UID:RUBYEVENTS-#{north_america.id}"
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

  private

  # Moves two fixtures into the upcoming window on different continents.
  def upcoming_events_on_two_continents
    europe = events(:rails_world_2023) # NL
    north_america = events(:railsconf_2025) # US

    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now)
    north_america.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now)

    [europe, north_america]
  end
end
