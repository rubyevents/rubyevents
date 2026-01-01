require "test_helper"

class WrappedControllerTest < ActionDispatch::IntegrationTest
  test "index shows wrapped landing page" do
    get wrapped_path

    assert_response :success
    assert_select "h1", "2025"
  end

  test "index shows sign in link when not logged in" do
    get wrapped_path

    assert_response :success
    assert_select "a", text: /Sign in to see your Wrapped/
  end

  test "index shows watch your wrapped link when logged in" do
    user = users(:one)
    sign_in_as(user)

    get wrapped_path

    assert_response :success
    assert_select "a[href=?]", profile_wrapped_index_path(profile_slug: user.slug), text: /Watch Your 2025 Wrapped/
  end

  test "index shows public user avatars" do
    user = users(:one)
    user.update!(wrapped_public: true)

    get wrapped_path

    assert_response :success
    assert_select "a[href=?]", profile_wrapped_index_path(profile_slug: user.slug)
  end
end
