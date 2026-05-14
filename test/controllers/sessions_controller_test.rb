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

  test "should sign out and redirect to native refresh when in hotwire native app" do
    sign_in_as @user

    delete session_url(@user.sessions.last), headers: {"User-Agent" => "Hotwire Native iOS"}
    assert_redirected_to hotwire_native_v1_refresh_path
  end

  test "exchange signs in user with valid token and redirects to native refresh" do
    token = @user.signed_id(purpose: :native_signin, expires_in: 60.seconds)

    get exchange_sessions_url(token: token)
    assert_redirected_to hotwire_native_v1_refresh_path
    assert_equal "Signed in successfully", flash[:notice]
  end

  test "exchange with invalid token redirects to new session" do
    get exchange_sessions_url(token: "invalid")
    assert_redirected_to new_session_path
    assert_equal "Sign-in link expired. Please try again.", flash[:alert]
  end
end
