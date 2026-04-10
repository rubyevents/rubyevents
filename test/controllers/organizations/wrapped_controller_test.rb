require "test_helper"

class Organizations::WrappedControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    organization = organizations(:one)
    get organization_wrapped_index_path(organization_slug: organization.slug)
    assert_response :success
  end

  test "should render organization wrapped content" do
    organization = organizations(:one)
    get organization_wrapped_index_path(organization_slug: organization.slug)
    assert_select "h1", text: /2025/
  end

  test "returns 404 for unknown organization" do
    get organization_wrapped_index_path(organization_slug: "nonexistent")
    assert_response :not_found
  end
end
