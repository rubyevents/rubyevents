require "test_helper"

class RequestedTalkTopicTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @topic = requested_talk_topics(:two)
  end

  #
  # Associations
  #

  test "belongs to user" do
    association = RequestedTalkTopic.reflect_on_association(:user)

    assert_equal :belongs_to, association.macro
  end

  test "has many requested talk topic votes" do
    association = RequestedTalkTopic.reflect_on_association(:requested_talk_topic_votes)

    assert_equal :has_many, association.macro
  end

  test "has many voters through requested talk topic votes" do
    association = RequestedTalkTopic.reflect_on_association(:voters)

    assert_equal :has_many, association.macro
  end

  #
  # Validations
  #

  test "is valid with valid attributes" do
    assert @topic.valid?
  end

  test "title is required" do
    @topic.title = nil

    assert_not @topic.valid?
    assert_includes @topic.errors[:title], "can't be blank"
  end

  test "description is required" do
    @topic.description = nil

    assert_not @topic.valid?
    assert_includes @topic.errors[:description], "can't be blank"
  end

  #
  # Enum
  #

  test "supports all statuses" do
    assert RequestedTalkTopic.statuses.key?("open")
    assert RequestedTalkTopic.statuses.key?("planned")
    assert RequestedTalkTopic.statuses.key?("presented")
    assert RequestedTalkTopic.statuses.key?("closed")
  end

  #
  # Search scope
  #

  test "search returns matching title" do
    results = RequestedTalkTopic.search("indexes")

    assert_includes results, @topic
  end

  test "search returns matching description" do
    results = RequestedTalkTopic.search("BRIN")

    assert_includes results, @topic
  end

  test "search is case insensitive" do
    results = RequestedTalkTopic.search("INDEXES")

    assert_includes results, @topic
  end

  test "search returns all records when query is blank" do
    assert_equal RequestedTalkTopic.count,
      RequestedTalkTopic.search(nil).count

    assert_equal RequestedTalkTopic.count,
      RequestedTalkTopic.search("").count
  end

  #
  # with_status scope
  #

  test "with_status filters records" do
    planned = requested_talk_topics(:two)
    open = requested_talk_topics(:one)

    results = RequestedTalkTopic.with_status("planned")

    assert_includes results, planned
    assert_not_includes results, open
  end

  test "with_status returns all when status is blank" do
    assert_equal RequestedTalkTopic.count,
      RequestedTalkTopic.with_status(nil).count
  end

  #
  # sorted scope
  #

  test "sorted newest" do
    newer = RequestedTalkTopic.create!(
      title: "Newest",
      description: "Newest topic",
      user: @user
    )

    newer.touch

    assert_equal newer,
      RequestedTalkTopic.sorted("newest").first
  end

  test "sorted oldest" do
    expected = RequestedTalkTopic.order(created_at: :asc).first

    assert_equal expected,
      RequestedTalkTopic.sorted("oldest").first
  end

  test "sorted by least votes" do
    expected = RequestedTalkTopic.order(votes_count: :asc).first

    assert_equal expected,
      RequestedTalkTopic.sorted("least_votes").first
  end

  test "default sorting is by most votes" do
    high_vote = RequestedTalkTopic.create!(
      title: "High Vote",
      description: "Popular topic",
      user: @user,
      votes_count: 20
    )

    assert_equal high_vote,
      RequestedTalkTopic.sorted(nil).first
  end

  test "destroys votes when topic is destroyed" do
    vote = requested_talk_topic_votes(:one)

    topic = vote.requested_talk_topic

    assert_difference("RequestedTalkTopicVote.count", -1) do
      topic.destroy
    end
  end
end
