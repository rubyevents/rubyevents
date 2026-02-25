require "test_helper"

class TopicTest < ActiveSupport::TestCase
  test "create_from_list" do
    topics = ["Rails", "Ruby", "Ruby on Rails"]
    statuses = ["pending", "approved", "rejected"]

    statuses.each do |status|
      created_topics = Topic.create_from_list(topics, status: status)
      assert_equal [status], created_topics.pluck(:status).uniq
      Topic.where(name: topics).destroy_all
    end
  end

  test "create_from_list shoudln't update status of exiting topic" do
    topic = Topic.create(name: "Ruby on Rails", status: :approved)
    assert_equal "approved", topic.status

    created_topics = Topic.create_from_list([topic.name], status: :pending)

    assert_equal 1, created_topics.length
    assert_equal "approved", created_topics.first.status
  end

  test "create_from_list with duplicated topics" do
    topics = ["Rails", "Rails", "Ruby", "Rails on Rails"]

    assert_changes "Topic.count", 3 do
      Topic.create_from_list(topics)
    end
  end

  test "can assign_canonical_topic!" do
    @talk = talks(:one)
    duplicate_topic = Topic.create(name: "Rails")
    TalkTopic.create!(topic: duplicate_topic, talk: @talk)
    canonical_topic = Topic.create(name: "Ruby on Rails")

    assert duplicate_topic.talks.ids.include?(@talk.id)
    duplicate_topic.assign_canonical_topic!(canonical_topic: canonical_topic)

    assert_equal canonical_topic, duplicate_topic.reload.canonical
    assert duplicate_topic.duplicate?
    assert duplicate_topic.reload.talks.empty?
    assert canonical_topic.reload.talks.ids.include?(@talk.id)
  end

  test "create_from_list with canonical topic" do
    topics = ["Rails", "Ruby on Rails"]
    canonical_topic = Topic.create(name: "Ruby on Rails", status: :approved)
    topic = Topic.create(name: "Rails", canonical: canonical_topic, status: :duplicate)

    assert_equal topic.primary_topic, canonical_topic
    assert_no_changes "Topic.count" do
      @topics = Topic.create_from_list(topics)
    end

    assert_equal 1, @topics.length
    assert_equal "Ruby on Rails", @topics.first.name
  end

  test "reject invalid topics" do
    @topic = topics(:one)
    assert @topic.talks.count.positive?
    @topic.rejected!
    assert @topic.talks.count.zero?
  end
end
