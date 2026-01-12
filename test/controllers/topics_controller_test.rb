require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @topic1 = Topic.create(name: "New Topic 1", status: :approved)
    @topic2 = Topic.create(name: "New Topic 2", status: :pending)

    @talk = talks(:one)
    @topic1.talks << @talk
  end

  test "should get index" do
    get topics_url
    assert_response :success
    assert_select "h1", "Topics"
    assert_select "##{dom_id(@topic1)} > span", "1"
    assert_select "##{dom_id(@topic2)}", 0

    @topic2.approved!
    get topics_url
    assert_response :success
    assert_select "##{dom_id(@topic2)}", 0
  end

  test "should get index with invalid page number" do
    get topics_url(page: "'")
    assert_response :success
    assert_select "h1", "Topics"
    assert_select "##{dom_id(@topic1)} > span", "1"
    assert_select "##{dom_id(@topic2)}", 0
  end

  test "should get show" do
    get topic_url(@topic1)
    assert_response :success
    assert_select "h1", @topic1.name
    assert_select "#topic-talks > div", 1
    assert_select "##{dom_id(@talk)} h2", @talk.title

    get topic_url(@topic2)
    assert_response :success
    assert_select "h1", @topic2.name
    assert_select "#topic-talks > div", 0
  end
end
