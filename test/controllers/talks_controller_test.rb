require "test_helper"

class TalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @talk = talks(:one)
    @event = events(:rails_world_2023)
    @talk.update(event: @event)
  end

  test "should get index" do
    get talks_url
    assert_response :success
  end

  test "should get index with search results" do
    get talks_url(s: "rails")
    assert_response :success
    assert_select "h1", /Talks/i
    assert_select "h1", /search results for "rails"/i
  end

  test "should get index with topic" do
    get talks_url(topic: "activerecord")
    assert_response :success
    assert assigns(:talks).size.positive?
    assert assigns(:talks).all? { |talk| talk.topics.map(&:slug).include?("activerecord") }
  end

  test "should get index with event" do
    get talks_url(event: "rails-world-2023")
    assert_response :success
    assert assigns(:talks).size.positive?
    assert assigns(:talks).all? { |talk| talk.event.slug == "rails-world-2023" }
  end

  test "should get index with speaker" do
    get talks_url(speaker: "yaroslav-shmarov")
    assert_response :success
    assert assigns(:talks).size.positive?
    assert assigns(:talks).all? { |talk| talk.speakers.map(&:slug).include?("yaroslav-shmarov") }
  end

  test "should show talk" do
    get talk_url(@talk)
    assert_response :success
  end

  test "should redirect to talks for wrong slugs" do
    get talk_url("wrong-slug")
    assert_response :moved_permanently
    assert_redirected_to talks_path
  end

  test "should redirect to correct talk slug when accessed via alias" do
    @talk.aliases.create!(name: "Old Title", slug: "old-talk-slug")

    get talk_url("old-talk-slug")
    assert_response :moved_permanently
    assert_redirected_to talk_path(@talk)
  end

  test "should get edit" do
    get edit_talk_url(@talk), headers: {"Turbo-Frame" => "modal"}
    assert_response :success
  end

  test "anonymous user can suggest a modification" do
    patch talk_url(@talk), params: {talk: {description: "new description", slug: "new-slug", title: "new title", date: "2024-01-01"}}
    assert_redirected_to talk_url(@talk)
    assert_equal "Your suggestion was successfully created and will be reviewed soon.", flash[:notice]
    assert_equal 1, @talk.suggestions.pending.count
    assert_not_equal "new description", @talk.reload.description
    assert_not_equal "new title", @talk.title
    assert_not_equal "2024-01-01", @talk.date.to_s
  end

  test "admin user can update talk" do
    @user = users(:admin)
    sign_in_as @user

    patch talk_url(@talk), params: {talk: {summary: "new summary", description: "new description", slug: "new-slug", title: "new title", date: "2024-01-01"}}
    assert_redirected_to talk_url(@talk)
    assert_equal "Modification approved!", flash[:notice]
    assert_equal 1, @talk.suggestions.approved.count
    assert_equal "new description", @talk.reload.description
    assert_equal "new summary", @talk.summary
    assert_equal "new title", @talk.title
    assert_equal "2024-01-01", @talk.date.to_s

    # some attributes cannot be changed
    assert_not_equal "new-slug", @talk.slug
  end

  test "owner can update directly the talk" do
    user = @talk.users.first
    sign_in_as user

    patch talk_url(@talk), params: {talk: {summary: "new summary", description: "new description", slug: "new-slug", title: "new title", date: "2024-01-01"}}
    assert_redirected_to talk_url(@talk)
    assert_equal "Modification approved!", flash[:notice]
    assert_equal 1, @talk.suggestions.approved.count
    assert_equal "new description", @talk.reload.description
    assert_equal "new summary", @talk.summary
    assert_equal "new title", @talk.title
    assert_equal "2024-01-01", @talk.date.to_s

    # some attributes cannot be changed
    assert_not_equal "new-slug", @talk.slug
  end

  test "should show topics" do
    # to remove when we remove the poor man FF for the topics
    @user = users(:admin)
    sign_in_as @user

    get talk_url(@talk)
    assert_select "a .badge", count: 1, text: "#activerecord"
    assert_select "a .badge", count: 0, text: "#rejected"
  end

  test "should get index as JSON" do
    get talks_url(format: :json)
    assert_response :success

    json_response = JSON.parse(response.body)
    talk = Talk.watchable.order(date: :desc).first

    assert_equal talk.slug, json_response["talks"].first["slug"]
  end

  test "should get index as JSON with a custom per_page" do
    assert Talk.watchable.count > 2
    get talks_url(format: :json, limit: 2)
    assert_response :success

    json_response = JSON.parse(response.body)

    assert_equal 2, json_response["talks"].size
  end

  test "should get show as JSON" do
    get talk_url(@talk, format: :json)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @talk.slug, json_response["talk"]["slug"]
  end

  test "should get index with created_after" do
    talk = Talk.create!(title: "test", description: "test", date: "2023-01-01", created_at: "2023-01-01", video_provider: "youtube", static_id: "test-created-after-2023")
    talk_2 = Talk.create!(title: "test 2", description: "test", date: "2025-01-01", created_at: "2025-01-01", video_provider: "youtube", static_id: "test-created-after-2025")

    get talks_url(created_after: "2024-01-01")
    assert_response :success
    assert assigns(:talks).size.positive?
    refute assigns(:talks).ids.include?(talk.id)
    assert assigns(:talks).ids.include?(talk_2.id)
    assert assigns(:talks).all? { |talk| talk.created_at >= Date.parse("2024-01-01") }
  end

  test "should get index with invalid created_after" do
    get talks_url(created_after: "wrong-date")
    assert_response :success
    assert assigns(:talks).size.positive?
  end
end
