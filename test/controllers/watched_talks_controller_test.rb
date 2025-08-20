require "test_helper"

class WatchedTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @talk_one = talks(:one)
    @talk_two = talks(:two)
    @talk_three = talks(:three)

    @watched_talk_one = watched_talks(:one)
    @watched_talk_three = watched_talks(:three)
    @watched_talk_two = watched_talks(:two)
  end

  test "should get index when authenticated" do
    sign_in_as @user

    get watched_talks_url
    assert_response :success
    assert_select "h1", /Recently Watched Videos/i
    assert_equal @user.watched_talks.count, assigns(:talks).count
  end

  test "should redirect to sign in when not authenticated" do
    get watched_talks_url
    assert_redirected_to new_session_url
  end

  test "should show only current user's watched talks" do
    sign_in_as @user

    get watched_talks_url
    assert_response :success

    assert assigns(:talks).include?(@watched_talk_one)
    assert assigns(:talks).include?(@watched_talk_three)

    assert_not assigns(:talks).include?(@watched_talk_two)
  end
end
