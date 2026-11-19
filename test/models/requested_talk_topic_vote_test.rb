require "test_helper"

class RequestedTalkTopicVoteTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @topic = requested_talk_topics(:two)
  end

  test "is valid with valid attributes" do
    vote = RequestedTalkTopicVote.new(
      user: @user,
      requested_talk_topic: @topic
    )

    assert vote.valid?
  end

  test "belongs to a user" do
    vote = RequestedTalkTopicVote.reflect_on_association(:user)

    assert_equal :belongs_to, vote.macro
  end

  test "belongs to a requested talk topic" do
    vote = RequestedTalkTopicVote.reflect_on_association(:requested_talk_topic)

    assert_equal :belongs_to, vote.macro
  end

  test "does not allow duplicate votes for the same user and topic" do
    RequestedTalkTopicVote.create!(
      user: @user,
      requested_talk_topic: @topic
    )

    duplicate_vote = RequestedTalkTopicVote.new(
      user: @user,
      requested_talk_topic: @topic
    )

    assert_not duplicate_vote.valid?
    assert_includes duplicate_vote.errors[:user_id], "has already been taken"
  end

  test "allows the same user to vote for different topics" do
    another_topic = requested_talk_topics(:three)

    RequestedTalkTopicVote.create!(
      user: @user,
      requested_talk_topic: @topic
    )

    vote = RequestedTalkTopicVote.new(
      user: @user,
      requested_talk_topic: another_topic
    )

    assert vote.valid?
  end

  test "allows different users to vote for the same topic" do
    another_user = users(:two)

    RequestedTalkTopicVote.create!(
      user: @user,
      requested_talk_topic: @topic
    )

    vote = RequestedTalkTopicVote.new(
      user: another_user,
      requested_talk_topic: @topic
    )

    assert vote.valid?
  end

  test "updates votes_count counter cache" do
    assert_difference("@topic.reload.votes_count", 1) do
      RequestedTalkTopicVote.create!(
        user: @user,
        requested_talk_topic: @topic
      )
    end
  end

  test "decrements votes_count when a vote is destroyed" do
    vote = RequestedTalkTopicVote.create!(
      user: @user,
      requested_talk_topic: @topic
    )

    assert_difference("@topic.reload.votes_count", -1) do
      vote.destroy
    end
  end
end
