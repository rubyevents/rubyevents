require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get organizations_url
    assert_response :success
  end

  test "should get show" do
    organization = organizations(:one)
    get organization_url(organization)
    assert_response :success
  end

  test "should redirect old sponsors path to organizations" do
    get "/sponsors"
    assert_redirected_to organizations_path
  end

  test "should redirect old sponsor show path to organization" do
    organization = organizations(:one)
    get "/sponsors/#{organization.slug}"
    assert_redirected_to organization_path(organization)
  end
end
