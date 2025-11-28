require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
  end

  test "should get new in a remote modal" do
    get new_session_url, headers: {"Turbo-Frame" => "modal"}
    assert_response :success
    assert_template "sessions/new"
  end

  test "should redirect to root when not in a remote modal" do
    get new_session_url
    assert_response :redirect
    assert_redirected_to root_url
  end

  test "should sign in" do
    post sessions_url, params: {email: @user.email, password: "Secret1*3*5*"}
    assert_redirected_to root_url

    get root_url
    assert_response :success
  end

  test "should not sign in with wrong credentials" do
    post sessions_url, params: {email: @user.email, password: "SecretWrong1*3"}
    assert_redirected_to new_session_url(email_hint: @user.email)
    assert_equal "That email or password is incorrect", flash[:alert]

    get admin_suggestions_url
    assert_redirected_to new_session_url
  end

  test "should sign out" do
    sign_in_as @user

    delete session_url(@user.sessions.last)
    assert_redirected_to root_url
  end
end
