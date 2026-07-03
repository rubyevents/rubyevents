require "test_helper"

class Organizations::LogosControllerTest < ActionDispatch::IntegrationTest
  test "should get 401 as a non-admin" do
    sign_in_as(users(:one))
    get organization_logos_path(organizations(:one))
    assert_response :unauthorized
  end

  test "should get show as an admin" do
    sign_in_as(users(:admin))
    get organization_logos_path(organizations(:one))
    assert_response :success
  end

  test "should get show with organization" do
    sign_in_as(users(:admin))
    get organization_logos_path(organizations(:one))
    assert_response :success
    assert_equal assigns(:organization), organizations(:one)
  end

  test "should get moved permanently if organization not found" do
    sign_in_as(users(:admin))
    get organization_logos_path("not-found")
    assert_response :moved_permanently
    assert_redirected_to organizations_path
    assert_equal "Organization not found", flash[:notice]
  end

  test "should update logo if user is admin" do
    sign_in_as(users(:admin))
    patch organization_logos_path(organizations(:one)), params: {organization: {logo_url: "https://example.com/logo.png", logo_background: "transparent"}}
    assert_response :redirect
    assert_redirected_to organization_logos_path(organizations(:one))
    assert_equal "https://example.com/logo.png", assigns(:organization).logo_url
    assert_equal "transparent", assigns(:organization).logo_background
    assert_equal "Updated successfully.", flash[:notice]
  end

  test "should not update logo if user is not admin" do
    sign_in_as(users(:one))
    patch organization_logos_path(organizations(:one)), params: {organization: {logo_url: "https://example.com/logo.png", logo_background: "transparent"}}
    assert_response :unauthorized
  end

  test "should redirect old sponsors logos path to organizations logos" do
    sign_in_as(users(:admin))
    get "/sponsors/#{organizations(:one).slug}/logos"
    assert_redirected_to organization_logos_path(organizations(:one))
  end
end
