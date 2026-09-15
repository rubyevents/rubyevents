require "test_helper"

class RequestedTalkTopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @topic = requested_talk_topics(:one)
  end

  test "should get index" do
    get requested_talk_topics_path

    assert_response :success
    assert_select "body"
  end

  test "index filters by query" do
    get requested_talk_topics_path,
      params: {query: "Rails"}

    assert_response :success
  end

  test "index filters by status" do
    get requested_talk_topics_path,
      params: {status: "open"}

    assert_response :success
  end

  test "index sorts by newest" do
    get requested_talk_topics_path,
      params: {sort: "newest"}

    assert_response :success
  end

  test "should show topic" do
    get requested_talk_topic_path(@topic)

    assert_response :success
  end

  test "should redirect new when not authenticated" do
    get new_requested_talk_topic_path

    assert_redirected_to new_session_path
  end

  test "should redirect create when not authenticated" do
    assert_no_difference("RequestedTalkTopic.count") do
      post requested_talk_topics_path,
        params: {
          requested_talk_topic: {
            title: "Postgres Locks",
            description: "Locking deep dive"
          }
        }
    end

    assert_redirected_to new_session_path
  end

  test "should get new when authenticated" do
    sign_in_as(@user)

    get new_requested_talk_topic_path

    assert_response :success
  end

  test "should create topic" do
    sign_in_as(@user)

    assert_difference("RequestedTalkTopic.count", 1) do
      post requested_talk_topics_path,
        params: {
          requested_talk_topic: {
            title: "MVCC Explained",
            description: "Deep dive into MVCC"
          }
        }
    end

    topic = RequestedTalkTopic.last

    assert_redirected_to requested_talk_topic_path(topic)
    assert_equal @user, topic.user
  end

  test "should not create invalid topic" do
    sign_in_as(@user)

    assert_no_difference("RequestedTalkTopic.count") do
      post requested_talk_topics_path,
        params: {
          requested_talk_topic: {
            title: "",
            description: ""
          }
        }
    end

    assert_response :unprocessable_entity
  end
end
