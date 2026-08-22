require "test_helper"

class WatchListTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @watch_list = watch_lists(:one)
    @talk = talks(:one)
    sign_in_as @user
  end

  test "adds and removes a bookmark without replacing its frame" do
    assert_difference("WatchListTalk.count") do
      post watch_list_talks_url(@watch_list), params: {talk_id: @talk.id}, as: :turbo_stream
    end

    assert_response :success
    assert_select bookmark_update_selector
    assert_includes @watch_list.talks, @talk

    assert_difference("WatchListTalk.count", -1) do
      delete watch_list_talk_url(@watch_list, @talk.id), as: :turbo_stream
    end

    assert_response :success
    assert_select bookmark_update_selector
    assert_not_includes @watch_list.talks, @talk
  end

  test "acks with no content for xhr toggles" do
    assert_difference("WatchListTalk.count") do
      post watch_list_talks_url(@watch_list), params: {talk_id: @talk.id}, xhr: true
    end

    assert_response :no_content
    assert_includes @watch_list.talks, @talk
  end

  test "remove is idempotent when the talk is not bookmarked" do
    assert_no_difference("WatchListTalk.count") do
      delete watch_list_talk_url(@watch_list, @talk.id), xhr: true
    end

    assert_response :no_content
  end

  private

  def bookmark_update_selector
    target = ActionView::RecordIdentifier.dom_id(@talk, :bookmark_button)
    "turbo-stream[action='update'][target='#{target}']"
  end
end
