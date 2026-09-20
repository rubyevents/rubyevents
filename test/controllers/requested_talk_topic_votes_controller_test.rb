require "test_helper"

class RequestedTalkTopicVotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @topic = requested_talk_topics(:two)

    sign_in_as @user
  end

  test "creates a vote if one does not exist" do
    assert_difference("RequestedTalkTopicVote.count", 1) do
      post requested_talk_topic_vote_path(
        requested_talk_topic_id: @topic.id
      )
    end

    assert_redirected_to requested_talk_topics_path

    vote = RequestedTalkTopicVote.last
    assert_equal @user, vote.user
    assert_equal @topic, vote.requested_talk_topic
  end

  test "removes the vote if it already exists" do
    RequestedTalkTopicVote.create!(
      user: @user,
      requested_talk_topic: requested_talk_topics(:two)
    )

    assert_difference("RequestedTalkTopicVote.count", -1) do
      post requested_talk_topic_vote_path(
        requested_talk_topic_id: @topic.id
      )
    end

    assert_redirected_to requested_talk_topics_path
  end
end
