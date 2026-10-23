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
