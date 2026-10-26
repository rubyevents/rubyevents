require "test_helper"

class EventSlugRedirectTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:future_conference)
    @event.slug_aliases.create!(name: "old-event-slug", slug: "old-event-slug")
  end

  test "redirects an event sub-page from an old slug to the current one" do
    get "/events/old-event-slug/talks"

    assert_response :moved_permanently
    assert_redirected_to "/events/#{@event.slug}/talks"
  end

  test "keeps the rest of the path and the query string" do
    get "/events/old-event-slug/schedule/day/2026-01-01?track=main"

    assert_response :moved_permanently
    assert_redirected_to "/events/#{@event.slug}/schedule/day/2026-01-01?track=main"
  end

  test "redirects routes that end with the event slug" do
    get "/events/attendances/old-event-slug"

    assert_response :moved_permanently
    assert_redirected_to "/events/attendances/#{@event.slug}"
  end

  test "redirects to a path on this site" do
    get "/events/old-event-slug/talks?redirect=https://example.org"

    assert_equal "www.example.com", URI(response.location).host
    assert_equal "/events/#{@event.slug}/talks", URI(response.location).path
  end

  test "redirects an old slug kept by the series to the series' only event" do
    series = EventSeries.create!(name: "Test Conf", slug: "test-conf", kind: "conference")
    event = Event.create!(name: "Test Conf 2025", slug: "test-conf-2025", series: series)
    series.aliases.create!(name: "testconf", slug: "testconf")

    get "/events/testconf/talks"

    assert_response :moved_permanently
    assert_redirected_to "/events/#{event.slug}/talks"
  end

  test "redirects an old slug of a meetup group with a single meetup to the group" do
    series = EventSeries.create!(name: "Philly.rb", slug: "phillyrb", kind: "meetup")
    Event.create!(name: "Philly.rb January 2026", slug: "phillyrb-2026-01-14", series: series, kind: "meetup", start_date: "2026-01-14", end_date: "2026-01-14")
    series.aliases.create!(name: "philly-rb", slug: "philly-rb")

    get "/events/philly-rb/talks"

    assert_response :moved_permanently
    assert_redirected_to "/events/series/phillyrb"
  end

  test "does not redirect the current slug" do
    get "/events/#{@event.slug}/talks"

    assert_response :success
  end

  test "does not redirect an unknown slug" do
    get "/events/no-such-event/talks"

    assert_not_equal "/events/no-such-event/talks", URI(response.location.to_s).path
    assert_not_includes response.location.to_s, @event.slug
  end
end
