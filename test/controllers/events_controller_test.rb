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

  test "should list past meetups among past events" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
    meetup = Event.create!(name: "Test.rb Meetup", slug: "testrb-2020-01-14", series: series, kind: :meetup, start_date: Date.yesterday, end_date: Date.yesterday)

    get past_events_url

    assert_response :success
    assert_select "[data-event-id=#{meetup.slug}]"
    assert_select "nav[aria-label=?] a", "Filter events by kind", text: /Meetups/
  end

  test "should leave events that aren't about Ruby out of the past and upcoming events" do
    series = EventSeries.create!(name: "Ruby talks at other events", slug: "ruby-talks-elsewhere", kind: :organisation)
    past = Event.create!(name: "SPLASH 2025", slug: "splash-2025", series: series, kind: :conference, start_date: Date.yesterday, end_date: Date.yesterday, ruby_focused: false)
    upcoming = Event.create!(name: "SPLASH 2099", slug: "splash-2099", series: series, kind: :conference, start_date: "2099-10-04", end_date: "2099-10-09", ruby_focused: false)

    get past_events_url
    assert_response :success
    assert_select "[data-event-id=#{past.slug}]", 0

    get events_url
    assert_response :success
    assert_select "[data-event-id=#{upcoming.slug}]", 0

    get event_url(past)
    assert_response :success
  end

  test "should filter upcoming events by kind and keep the continent" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
    meetup = Event.create!(name: "Test.rb Meetup", slug: "testrb-2099-01-14", series: series, kind: :meetup, start_date: "2099-01-14", end_date: "2099-01-14", country_code: "CH")

    get events_url(kind: "meetup", continent: "europe")

    assert_response :success
    assert_select "nav[aria-label=?] a[aria-current=page]", "Filter events by kind", text: /Meetups/
    assert_select "[data-event-id=#{meetup.slug}]"
    assert_select "[data-event-id=#{@event.slug}]", 0
    assert_select "nav[aria-label=?] a[href=?]", "Filter events by continent", "/events?continent=asia&kind=meetup"
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

  test "should redirect the former events tab to the event" do
    get "/events/#{@event.slug}/events"
    assert_redirected_to event_path(@event)
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

  test "should redirect an old event slug kept by its series to the series' only event" do
    series = EventSeries.create!(name: "Test Conf", slug: "test-conf", kind: "conference")
    event = Event.create!(name: "Test Conf 2025", slug: "test-conf-2025", series: series)
    series.aliases.create!(name: "testconf", slug: "testconf")

    get event_url("testconf")

    assert_response :moved_permanently
    assert_redirected_to event_path(event)
  end

  test "should redirect an old slug of a meetup group with a single meetup to the group" do
    series = EventSeries.create!(name: "Philly.rb", slug: "phillyrb", kind: "meetup")
    Event.create!(name: "Philly.rb January 2026", slug: "phillyrb-2026-01-14", series: series, kind: "meetup", start_date: "2026-01-14", end_date: "2026-01-14")
    series.aliases.create!(name: "phillyrb-meetup", slug: "phillyrb-meetup")

    get event_url("phillyrb-meetup")

    assert_response :moved_permanently
    assert_redirected_to series_path(series)
  end

  test "should redirect a series slug to the series when the series has several events" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: "meetup")
    Event.create!(name: "Test.rb 2025", slug: "testrb-2025", series: series)
    Event.create!(name: "Test.rb 2026", slug: "testrb-2026", series: series)

    get event_url("testrb")

    assert_response :moved_permanently
    assert_redirected_to series_path(series)
  end

  test "should redirect the slug of an event merged into a series to the series" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: "meetup")
    Event.create!(name: "Test.rb Meetup January 2026", slug: "testrb-2026-01-14", series: series, kind: "meetup", start_date: "2026-01-14", end_date: "2026-01-14")
    Event.create!(name: "Test.rb Meetup February 2026", slug: "testrb-2026-02-11", series: series, kind: "meetup", start_date: "2026-02-11", end_date: "2026-02-11")
    series.aliases.create!(name: "testrb-meetup", slug: "testrb-meetup")

    get event_url("testrb-meetup")

    assert_response :moved_permanently
    assert_redirected_to series_path(series)
  end

  test "should redirect the slug of a talk that became a meetup to the meetup" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: "meetup")
    meetup = Event.create!(name: "Test.rb Meetup January 2026", slug: "testrb-2026-01-14", series: series, kind: "meetup", start_date: "2026-01-14", end_date: "2026-01-14")
    meetup.slug_aliases.create!(name: "testrb-meetup-january-2026", slug: "testrb-meetup-january-2026")

    get talk_url("testrb-meetup-january-2026")

    assert_response :moved_permanently
    assert_redirected_to event_path(meetup)
  end

  test "should link a meetup without links of its own to its group's website" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: "meetup")
    meetup = Event.create!(name: "Test.rb Meetup January 2099", slug: "testrb-2099-01-14", series: series, kind: "meetup", start_date: "2099-01-14", end_date: "2099-01-14")
    static_series = Static::EventSeries.new(id: "testrb", name: "Test.rb", kind: "meetup", website: "https://testrb.org/")

    Static::EventSeries.stub(:find_by_slug, ->(slug) { static_series if slug == "testrb" }) do
      get event_url(meetup)
    end

    assert_response :success
    assert_select "aside a[href=?]", "https://testrb.org/", text: "Visit testrb.org"
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
