require "test_helper"

class Sponsors::LogosControllerTest < ActionDispatch::IntegrationTest
  test "should get 401 as a non-admin" do
    sign_in_as(users(:one))
    get sponsor_logos_path(sponsors(:one))
    assert_response :unauthorized
  end

  test "should get show as an admin" do
    sign_in_as(users(:admin))
    get sponsor_logos_path(sponsors(:one))
    assert_response :success
  end

  test "should get show with sponsor" do
    sign_in_as(users(:admin))
    get sponsor_logos_path(sponsors(:one))
    assert_response :success
    assert_equal assigns(:sponsor), sponsors(:one)
  end

  test "should get moved permanently if sponsor not found" do
    sign_in_as(users(:admin))
    get sponsor_logos_path("not-found")
    assert_response :moved_permanently
    assert_redirected_to sponsors_path
    assert_equal "Sponsor not found", flash[:notice]
  end

  test "should update logo if user is admin" do
    sign_in_as(users(:admin))
    patch sponsor_logos_path(sponsors(:one)), params: {sponsor: {logo_url: "https://example.com/logo.png", logo_background: "transparent"}}
    assert_response :redirect
    assert_redirected_to sponsor_logos_path(sponsors(:one))
    assert_equal "https://example.com/logo.png", assigns(:sponsor).logo_url
    assert_equal "transparent", assigns(:sponsor).logo_background
    assert_equal "Updated successfully.", flash[:notice]
  end

  test "should not update logo if user is not admin" do
    sign_in_as(users(:one))
    patch sponsor_logos_path(sponsors(:one)), params: {sponsor: {logo_url: "https://example.com/logo.png", logo_background: "transparent"}}
    assert_response :unauthorized
  end
end
