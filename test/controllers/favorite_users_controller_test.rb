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

  test "should update favorite_user notes" do
    favorite_user = favorite_users(:one)
    patch favorite_user_url(favorite_user), params: {favorite_user: {notes: "Met at dinner at Blue Ridge Ruby"}}
    assert_redirected_to favorite_users_url
    favorite_user.reload
    assert_equal "Met at dinner at Blue Ridge Ruby", favorite_user.notes
  end

  test "User is unfavorited while taking notes" do
    favorite_user = favorite_users(:one)
    delete favorite_user_url(favorite_user)
    patch favorite_user_url(favorite_user), params: {favorite_user: {notes: "This note should not be saved"}}
    assert_response :not_found
  end

  test "should not destroy another user's favorite_user" do
    # favorite_users(:two) belongs to users(:two), but we're signed in as users(:one).
    other_users_favorite = favorite_users(:two)

    assert_no_difference("FavoriteUser.count") do
      delete favorite_user_url(other_users_favorite)
    end

    assert_response :not_found
    assert FavoriteUser.exists?(other_users_favorite.id)
  end

  test "should not update another user's favorite_user" do
    # favorite_users(:two) belongs to users(:two), but we're signed in as users(:one).
    other_users_favorite = favorite_users(:two)

    patch favorite_user_url(other_users_favorite), params: {favorite_user: {notes: "Should not be saved"}}

    assert_response :not_found
    assert_nil other_users_favorite.reload.notes
  end
end
