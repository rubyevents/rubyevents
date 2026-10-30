require "test_helper"

class Events::EventSeriesSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event_series = event_series(:railsconf)
    @user = users(:one)
  end

  test "signed in user can follow a series" do
    sign_in_as @user

    assert_difference -> { @user.event_series_subscriptions.count }, 1 do
      post series_event_series_subscriptions_url(@event_series)
    end

    assert_redirected_to series_path(@event_series)
  end

  test "following a series replaces the follow buttons" do
    sign_in_as @user

    post series_event_series_subscriptions_url(@event_series), headers: {"Accept" => "text/vnd.turbo-stream.html"}

    assert_response :success
    assert_select "turbo-stream[action=replace][targets=?]", ".follow_button"
    assert_includes response.body, "Following"
  end

  test "signed in user can unfollow a series" do
    sign_in_as @user
    subscription = @user.event_series_subscriptions.create!(event_series: @event_series)

    assert_difference -> { @user.event_series_subscriptions.count }, -1 do
      delete series_event_series_subscription_url(@event_series, subscription)
    end

    assert_redirected_to series_path(@event_series)
  end

  test "signed out user can't follow a series" do
    assert_no_difference -> { EventSeriesSubscription.count } do
      post series_event_series_subscriptions_url(@event_series)
    end
  end
end
