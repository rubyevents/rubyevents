require "test_helper"

class WatchedTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user_two = users(:two)
  end

  test "should show only current user's watched talks" do
    sign_in_as @user

    get watched_talks_url
    assert_response :success

    talk_ids = assigns(:talks).map(&:id)
    user_watched_talk_ids = @user.watched_talks.pluck(:talk_id)

    assert_equal user_watched_talk_ids.sort, talk_ids.sort
  end

  test "should set user favorite talk ids from default watch list" do
    sign_in_as @user

    get watched_talks_url
    assert_response :success

    expected_favorite_ids = @user.default_watch_list.talks.ids
    actual_favorite_ids = assigns(:user_favorite_talks_ids)

    assert_equal expected_favorite_ids.sort, actual_favorite_ids.sort
  end
end
