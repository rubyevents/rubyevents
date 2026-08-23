require "test_helper"
require "rss"

class Events::ConferencesControllerTest < ActionDispatch::IntegrationTest
  test "publishes eligible conferences as RSS by default" do
    today = Date.new(2026, 2, 28)
    eligible = events(:future_conference)
    eligible.update!(start_date: Date.new(2026, 3, 31), end_date: Date.new(2026, 3, 31))

    events(:new_rb_meetup).update!(start_date: today + 1.week, end_date: today + 1.week)
    events(:rubyconfth_2022).update!(start_date: today + 2.months, end_date: today + 2.months)
    events(:rails_world_2023).update!(start_date: today + 2.weeks, end_date: today + 2.weeks, date_precision: :year)
    events(:brightonruby_2024).update!(start_date: today + 1.week, end_date: today + 1.week, canonical: events(:railsconf_2017))

    travel_to today do
      get conferences_url
    end

    feed = RSS::Parser.parse(response.body)
    item_urls = feed.items.map(&:link)
    item = feed.items.find { |feed_item| feed_item.link == event_url(eligible) }

    assert_response :success
    assert_equal "application/rss+xml; charset=utf-8", response.content_type
    assert_equal "Upcoming Ruby Conferences – RubyEvents.org", feed.channel.title
    assert_includes item_urls, event_url(eligible)
    assert_not_includes item_urls, event_url(events(:new_rb_meetup))
    assert_not_includes item_urls, event_url(events(:rubyconfth_2022))
    assert_not_includes item_urls, event_url(events(:rails_world_2023))
    assert_not_includes item_urls, event_url(events(:brightonruby_2024))
    assert_equal (eligible.start_date - 1.month).to_time, item.pubDate
  end

  test "rejects HTML" do
    get conferences_url(format: :html)

    assert_response :not_acceptable
  end
end
