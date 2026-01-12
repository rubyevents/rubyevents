require "test_helper"

class FavoriteUsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get index" do
    get favorite_users_url
    assert_response :success
  end

  test "should create favorite_user" do
    fav_user = users :marco

    assert_difference("FavoriteUser.count") do
      post favorite_users_url, params: {favorite_user: {favorite_user_id: fav_user.id}}
    end

    assert_redirected_to favorite_users_url
  end

  test "should destroy favorite_user" do
    favorite_user = favorite_users(:one)

    assert_difference("FavoriteUser.count", -1) do
      delete favorite_user_url(favorite_user)
    end

    assert_redirected_to favorite_users_url
  end
end
