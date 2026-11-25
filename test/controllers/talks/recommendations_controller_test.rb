require "test_helper"

class Talks::RecommendationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @talk = talks(:one)
  end

  test "should get index with a turbo stream request" do
    get talk_recommendations_url(@talk), headers: {"Turbo-Frame" => "true"}
    assert_response :success
    assert_equal assigns(:talk).id, @talk.id
    assert_not_nil assigns(:talks)
  end

  test "should return random talk if no talk is found" do
    get talk_recommendations_url("999999999"), headers: {"Turbo-Frame" => "true"}
    assert_response :success
    assert_not_nil assigns(:talks)
  end

  test "a none turbo stream request should redirect to the talk" do
    get talk_recommendations_url(@talk)
    assert_redirected_to talk_url(@talk)
  end

  test "a non turbo frame request for an unknown talk redirects to the talks index" do
    get talk_recommendations_url("unknown-talk-slug")
    assert_redirected_to talks_url
  end

  test "a non turbo frame request for an aliased talk redirects to the canonical talk" do
    @talk.aliases.create!(name: "Old Talk Title", slug: "old-talk-slug")

    get talk_recommendations_url("old-talk-slug")
    assert_redirected_to talk_url(@talk)
  end

  test "a turbo frame request for an aliased talk finds the talk" do
    @talk.aliases.create!(name: "Old Talk Title", slug: "old-talk-slug")

    get talk_recommendations_url("old-talk-slug"), headers: {"Turbo-Frame" => "true"}
    assert_response :success
    assert_equal @talk.id, assigns(:talk).id
  end
end
