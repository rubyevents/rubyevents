require "test_helper"

class EventSeriesSubscriptionTest < ActiveSupport::TestCase
  test "user can follow an event series" do
    user = users(:one)
    series = event_series(:railsconf)

    follow = EventSeriesSubscription.create(user: user, event_series: series)
    assert follow.persisted?
    assert_includes user.subscribed_event_series, series
    assert_includes series.subscribers, user
  end

  test "user cannot follow the same series twice" do
    user = users(:one)
    series = event_series(:railsconf)

    EventSeriesSubscription.create!(user: user, event_series: series)
    duplicate = EventSeriesSubscription.new(user: user, event_series: series)
    assert_not duplicate.valid?
  end

  test "user can follow multiple series" do
    user = users(:one)
    series1 = event_series(:railsconf)
    series2 = EventSeries.create!(name: "RubyConf", slug: "rubyconf")

    EventSeriesSubscription.create!(user: user, event_series: series1)
    EventSeriesSubscription.create!(user: user, event_series: series2)
    assert_equal 2, user.event_series_subscriptions.count
  end
end
