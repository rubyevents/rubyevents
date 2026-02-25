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
end
