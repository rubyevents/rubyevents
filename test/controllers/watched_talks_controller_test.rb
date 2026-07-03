require "test_helper"

class WatchedTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user_two = users(:two)
    @watched_talk = watched_talks(:one)
    @other_watched_talk = watched_talks(:two)
  end

  test "should show only current user's watched talks" do
    sign_in_as @user

    get watched_talks_url
    assert_response :success

    watched_talks_by_date = assigns(:watched_talks_by_date)
    talk_ids = watched_talks_by_date.values.flatten.map(&:talk_id)
    user_watched_talk_ids = @user.watched_talks.watched.pluck(:talk_id)

    assert_equal user_watched_talk_ids.sort, talk_ids.sort
  end

  test "should filter watched talks by in-person" do
    sign_in_as @user

    get watched_talks_url(filter: "in_person")
    assert_response :success

    talk_ids = assigns(:watched_talks_by_date).values.flatten.map(&:talk_id)
    expected_ids = @user.watched_talks.watched.where(watched_on: "in_person").pluck(:talk_id)

    assert_equal expected_ids.sort, talk_ids.sort
    assert_equal expected_ids.size, assigns(:in_person_count)
  end

  test "should filter watched talks by online (includes unspecified)" do
    sign_in_as @user

    get watched_talks_url(filter: "online")
    assert_response :success

    talk_ids = assigns(:watched_talks_by_date).values.flatten.map(&:talk_id)
    expected_ids = @user.watched_talks.watched.where("watched_on IS NULL OR watched_on != ?", "in_person").pluck(:talk_id)

    assert_equal expected_ids.sort, talk_ids.sort
    assert_equal expected_ids.size, assigns(:online_count)
  end

  test "filter counts add up to the total" do
    sign_in_as @user

    get watched_talks_url
    assert_response :success

    assert_equal assigns(:watched_count), assigns(:in_person_count) + assigns(:online_count)
  end

  test "should destroy watched talk for current user" do
    sign_in_as @user

    delete watched_talk_path(@watched_talk)

    assert_redirected_to watched_talks_path

    assert_not WatchedTalk.exists?(@watched_talk.id)
  end

  test "should destroy watched talk with turbo stream" do
    sign_in_as @user

    delete watched_talk_path(@watched_talk), headers: {"Accept" => "text/vnd.turbo-stream.html"}

    assert_turbo_stream action: "remove", target: dom_id(@watched_talk.talk, :card_horizontal)

    assert_not WatchedTalk.exists?(@watched_talk.id)
  end
end
