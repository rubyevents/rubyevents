require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "user can follow an event series" do
    user = users(:one)
    series = event_series(:railsconf)

    subscription = Subscription.create(user: user, subscribable: series)
    assert subscription.persisted?
    assert_includes user.subscribed_event_series, series
    assert_includes series.subscribers, user
  end

  test "user cannot follow the same series twice" do
    user = users(:one)
    series = event_series(:railsconf)

    Subscription.create!(user: user, subscribable: series)
    duplicate = Subscription.new(user: user, subscribable: series)
    assert_not duplicate.valid?
  end

  test "user can follow multiple series" do
    user = users(:one)
    series1 = event_series(:railsconf)
    series2 = EventSeries.create!(name: "RubyConf", slug: "rubyconf")

    Subscription.create!(user: user, subscribable: series1)
    Subscription.create!(user: user, subscribable: series2)
    assert_equal 2, user.subscribed_event_series.count
  end

  test "user cannot follow themselves" do
    user = users(:one)

    subscription = Subscription.new(user: user, subscribable: user)
    assert_not subscription.valid?
    assert_includes subscription.errors[:subscribable], "can't be yourself"
  end

  test "a user's favorites are only their subscriptions to users" do
    chael = users(:chael)
    favorite = FavoriteUser.create!(user: chael, favorite_user: users(:marco))
    Subscription.create!(user: chael, subscribable: event_series(:railsconf))

    assert_equal [favorite], chael.favorite_users.to_a
    assert_equal 2, chael.subscriptions.count
  end
end
