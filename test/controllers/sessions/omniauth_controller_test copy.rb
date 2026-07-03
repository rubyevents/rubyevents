require "test_helper"

class Sessions::OmniauthControllerTest < ActionDispatch::IntegrationTest
  def setup
    OmniAuth.config.test_mode = true
    developer = connected_accounts(:developer_connected_account)
    @developer_user = developer.user
    @developer_auth = OmniAuth::AuthHash.new(developer.attributes
                                                      .slice("provider", "uid")
                                                      .merge({info: {email: developer.user.email}}))

    github = connected_accounts(:github_connected_account)
    @user = github.user
    @github_auth = OmniAuth::AuthHash.new(github.attributes
                                          .slice("provider", "uid")
                                          .merge({info: {email: github.user.email}}))
  end

  def teardown
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
    OmniAuth.config.mock_auth[:developer] = nil
  end

  test "creates a new user if not exists (developer)" do
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(uid: "12345", info: {github_handle: "new-user", name: "New User"})

    assert_difference "User.count", 1 do
      post "/auth/developer/callback"
    end
    user = User.find_by_github_handle("new-user")
    assert_equal 1, user.connected_accounts.count
    OmniAuth.config.mock_auth[:developer] = nil
  end

  test "creates a new user if not exists (github)" do
    OmniAuth.config.add_mock(:github, uid: "12345", info: {email: "twitter@example.com", nickname: "twitter"}, credentials: {token: 1, expires_in: 100})
    assert_difference "User.count", 1 do
      post "/auth/github/callback"
    end

    assert_equal "twitter", User.last.connected_accounts.last.username
    assert_equal "twitter", User.last.github_handle
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "finds existing user if already exists (developer)" do
    OmniAuth.config.mock_auth[:developer] = @developer_auth
    assert_no_difference "User.count" do
      post "/auth/developer/callback"
    end
    assert_redirected_to root_path
    OmniAuth.config.mock_auth[:developer] = nil
  end

  test "finds existing user if already exists (github)" do
    OmniAuth.config.mock_auth[:github] = @github_auth
    assert_no_difference "User.count" do
      post "/auth/github/callback"
    end
    assert_redirected_to root_path
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "assign a passport to the existing user (github)" do
    connected_account = connected_accounts(:github_connected_account)

    OmniAuth.config.before_callback_phase = lambda do |env|
      env["omniauth.params"] = {"redirect_to" => "/", "state" => "connect_id:abcde34"}
    end

    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: :github,
      uid: connected_account.uid,
      info: {email: @user.email},
      params: {
        redirect_to: profile_path(@user),
        state: "connect_id:123456"
      }
    )
    assert_no_difference "User.count" do
      post "/auth/github/callback"
    end

    assert_redirected_to profile_path(@user)
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "full oauth flow" do
    OmniAuth.config.mock_auth[:github] = @github_auth
    state = "connect_id:123456"

    # Start the auth request with the state
    post "/auth/github?state=#{state}"
    follow_redirect!  # goes to /auth/github/callback

    assert_redirected_to profile_path(@user)
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "finds existing user by email if already exists and creates a new connected account(github)" do
    user = users(:one)
    OmniAuth.config.add_mock(:github, uid: "12345", info: {email: user.email, nickname: "one"})
    assert user.connected_accounts.empty?
    assert_difference "ConnectedAccount.count", 1 do
      post "/auth/github/callback"
    end
    assert_equal ConnectedAccount.last.user, user
    assert_equal ConnectedAccount.last.username, "one"
    assert_redirected_to root_path
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "creates a new session for the user" do
    OmniAuth.config.mock_auth[:developer] = @developer_auth
    assert_difference "Session.count", 1 do
      post "/auth/developer/callback"
    end
  end

  test "sets a session token cookie" do
    OmniAuth.config.mock_auth[:developer] = @developer_auth
    post "/auth/developer/callback"
    assert_not_nil cookies["session_token"]
    OmniAuth.config.mock_auth[:developer] = nil
  end

  test "redirects to root_path with a success notice" do
    OmniAuth.config.mock_auth[:developer] = @developer_auth
    post "/auth/developer/callback"
    assert_redirected_to root_path
    assert_equal "Signed in successfully", flash[:notice]
    OmniAuth.config.mock_auth[:developer] = nil
  end
end
