require "test_helper"

class Hotwire::Native::V1::OauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "renders sign-in buttons when signed out" do
    get hotwire_native_v1_oauth_url
    assert_response :success
    assert_select "form[action^='/auth/github']"
  end

  test "renders sign-out button when signed in" do
    sign_in_as @user

    get hotwire_native_v1_oauth_url
    assert_response :success
    assert_select "form[action='#{session_path(@user.sessions.last)}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
    end
  end
end
