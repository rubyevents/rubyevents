require "test_helper"

class Events::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event_series = event_series(:railsconf)
    @user = users(:one)
  end

  test "signed in user can follow a series" do
    sign_in_as @user

    assert_difference -> { @user.subscribed_event_series.count }, 1 do
      post series_subscriptions_url(@event_series)
    end

    assert_redirected_to series_path(@event_series)
  end

  test "following a series replaces the follow buttons" do
    sign_in_as @user

    post series_subscriptions_url(@event_series), headers: {"Accept" => "text/vnd.turbo-stream.html"}

    assert_response :success
    assert_select "turbo-stream[action=replace][targets=?]", ".follow_button"
    assert_includes response.body, "Following"
  end

  test "following a series twice keeps one subscription" do
    sign_in_as @user
    @user.subscriptions.create!(subscribable: @event_series)

    assert_no_difference -> { Subscription.count } do
      post series_subscriptions_url(@event_series), headers: {"Accept" => "text/vnd.turbo-stream.html"}
    end

    assert_response :success
    assert_includes response.body, "Following"
  end

  test "signed in user can unfollow a series" do
    sign_in_as @user
    subscription = @user.subscriptions.create!(subscribable: @event_series)

    assert_difference -> { @user.subscribed_event_series.count }, -1 do
      delete series_subscription_url(@event_series, subscription)
    end

    assert_redirected_to series_path(@event_series)
  end

  test "signed out user can't follow a series" do
    assert_no_difference -> { Subscription.count } do
      post series_subscriptions_url(@event_series)
    end
  end
end
