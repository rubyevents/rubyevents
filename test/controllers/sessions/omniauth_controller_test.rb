require "test_helper"

class Sessions::OmniauthControllerTest < ActionDispatch::IntegrationTest
  def setup
    OmniAuth.config.test_mode = true
    developer = connected_accounts(:developer_connected_account)
    @developer_auth = OmniAuth::AuthHash.new(developer.attributes
                                                      .slice("provider", "uid")
                                                      .merge({info: {email: developer.user.email}}))

    github = connected_accounts(:github_connected_account)
    @github_auth = OmniAuth::AuthHash.new(github.attributes
                                          .slice("provider", "uid")
                                          .merge({info: {email: github.user.email}}))
  end

  test "creates a new user if not exists (developer)" do
    OmniAuth.config.add_mock(:developer, uid: "12345", info: {github_handle: "new-user", name: "New User"})

    assert_difference "User.count", 1 do
      post "/auth/developer/callback"
    end
    user = User.find_by(github_handle: "new-user")
    assert_equal 1, user.connected_accounts.count
  end

  test "creates a new user if not exists (github)" do
    OmniAuth.config.add_mock(:github, uid: "12345", info: {email: "twitter@example.com", nickname: "twitter"}, credentials: {token: 1, expires_in: 100})
    assert_difference "User.count", 1 do
      post "/auth/github/callback"
    end

    assert_equal "twitter", User.last.connected_accounts.last.username
    assert_equal "twitter", User.last.github_handle
  end

  test "finds existing user if already exists (developer)" do
    OmniAuth.config.mock_auth[:developer] = @developer_auth
    assert_no_difference "User.count" do
      post "/auth/developer/callback"
    end
    assert_redirected_to root_path
  end

  test "finds existing user if already exists (github)" do
    OmniAuth.config.mock_auth[:github] = @github_auth
    assert_no_difference "User.count" do
      post "/auth/github/callback"
    end
    assert_redirected_to root_path
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
  end

  test "redirects to root_path with a success notice" do
    OmniAuth.config.mock_auth[:developer] = @developer_auth
    post "/auth/developer/callback"
    assert_redirected_to root_path
    assert_equal "Signed in successfully", flash[:notice]
  end
end
