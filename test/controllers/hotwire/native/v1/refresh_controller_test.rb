require "test_helper"

class Hotwire::Native::V1::RefreshControllerTest < ActionDispatch::IntegrationTest
  test "renders successfully when signed out" do
    get hotwire_native_v1_refresh_url
    assert_response :success
  end

  test "renders successfully when signed in" do
    sign_in_as users(:lazaro_nixon)

    get hotwire_native_v1_refresh_url
    assert_response :success
  end
end
