require "test_helper"

class RecommendationsControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to login when accessing recommendations without authentication" do
    get recommendations_path
    assert_redirected_to new_session_path
  end

  test "should get recommendations page when authenticated" do
    user = users(:one)
    sign_in_as user

    get recommendations_path
    assert_response :success
    assert_select "h2", "Recommended for you"
  end

  test "should display no recommendations message when user has no watch history" do
    user = users(:one)
    sign_in_as user

    get recommendations_path
    assert_response :success
    assert_select "p", text: /No recommendations available yet/
    assert_select "p", text: /Watch some talks to get personalized recommendations/
  end
end
