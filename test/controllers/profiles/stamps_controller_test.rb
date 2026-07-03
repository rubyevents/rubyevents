require "test_helper"

class Profiles::StampsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:yaroslav)
    sign_in_as(@user)
  end

  test "should redirect user if GitHub handle is different than profile slug" do
    get profile_stamps_path(profile_slug: @user.slug)
    assert_response :redirect
    assert_redirected_to profile_stamps_path(profile_slug: @user.github_handle)
    follow_redirect!
    assert_response :success
  end
end
