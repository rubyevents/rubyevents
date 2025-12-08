require "test_helper"

class Talks::WatchedTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @talk = talks(:one)
    @watched_talk = watched_talks(:one)
  end

  test "should update watched talk progress for authenticated user" do
    sign_in_as @user

    initial_progress = @watched_talk.progress_seconds
    new_progress = 150

    patch talk_watched_talk_path(@talk), params: {
      watched_talk: {progress_seconds: new_progress}
    }

    assert_response :ok
    assert_equal new_progress, @watched_talk.reload.progress_seconds
    assert_not_equal initial_progress, @watched_talk.progress_seconds
  end
end
