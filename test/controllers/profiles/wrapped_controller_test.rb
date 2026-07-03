require "test_helper"

class Profiles::WrappedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    sign_in_as(@user)
  end

  test "should get wrapped page for user" do
    get profile_wrapped_index_path(profile_slug: @user.slug)
    assert_response :success
    assert_includes response.body, "2025"
    assert_includes response.body, "Wrapped"
    assert_includes response.body, @user.name
  end

  test "should show watching stats section" do
    get profile_wrapped_index_path(profile_slug: @user.slug)
    assert_response :success
    assert_includes response.body, "Your Watching Journey"
    assert_includes response.body, "Talks Watched"
  end

  test "should show top topics section" do
    get profile_wrapped_index_path(profile_slug: @user.slug)
    assert_response :success
    assert_includes response.body, "Your Top Topics"
  end

  test "should show events attended section" do
    get profile_wrapped_index_path(profile_slug: @user.slug)
    assert_response :success
    assert_includes response.body, "Events Attended"
  end

  test "should show closing page" do
    get profile_wrapped_index_path(profile_slug: @user.slug)
    assert_response :success
    assert_includes response.body, "That's a Wrap!"
    assert_includes response.body, "RubyEvents.org"
  end

  test "should generate og image" do
    skip "flaky test" if ENV["CI"]

    get og_image_profile_wrapped_index_path(profile_slug: @user.slug)
    assert_response :redirect
    assert_match %r{active_storage/blobs}, response.location
  end
end
