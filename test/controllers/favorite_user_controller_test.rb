require "test_helper"

class FavoriteUserControllerTest < ActionDispatch::IntegrationTest
  test "should get update" do
    get favorite_user_update_url
    assert_response :success
  end
end
