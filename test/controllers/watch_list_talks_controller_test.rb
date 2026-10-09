require "test_helper"

class WatchListTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @watch_list = watch_lists(:one)
    @talk = talks(:one)
    sign_in_as @user
  end

  test "should add talk to watch_list and redirect for turbo submissions" do
    assert_difference("WatchListTalk.count") do
      post watch_list_talks_url(@watch_list), params: {talk_id: @talk.id}, as: :turbo_stream
    end

    assert_redirected_to watch_list_url(@watch_list)
    assert_includes @watch_list.talks, @talk
  end

  test "should remove talk from watch_list and redirect for turbo submissions" do
    WatchListTalk.create!(watch_list: @watch_list, talk: @talk)

    assert_difference("WatchListTalk.count", -1) do
      delete watch_list_talk_url(@watch_list, @talk.id), as: :turbo_stream
    end

    assert_redirected_to watch_list_url(@watch_list)
    assert_not_includes @watch_list.talks, @talk
  end

  test "should ack with no content for xhr (request.js) toggles" do
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
end
