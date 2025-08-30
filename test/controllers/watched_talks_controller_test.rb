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
end
