require "test_helper"

class Profiles::ConnectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update(connect_id: "one")

    @lazaro = users(:lazaro_nixon)
    @lazaro.update(connect_id: "lazaro")
  end

  test "should redirect to root path" do
    get profiles_connect_index_path
    assert_redirected_to root_path
  end

  test "guest should see the claim profile page" do
    get profiles_connect_path(id: "marco")
    assert_response :success
    assert_includes response.body, "🎉 Profile Ready to Claim!"
  end

  test "guest should see the friend prompt page" do
    get profiles_connect_path(id: "one")
    assert_response :success
    assert_includes response.body, "🎉 Awesome! You Discovered a Friend"
    assert_includes response.body, "Sign In and Connect"
  end

  test "user should see the friend prompt page" do
    sign_in_as @lazaro
    get profiles_connect_path(id: "one")
    assert_response :success
    assert_includes response.body, "🎉 Awesome! You Discovered a Friend"
    assert_select ".pt-4 a.btn.btn-primary", text: "Connect"
  end

  test "user should see no profile found page" do
    sign_in_as @lazaro
    get profiles_connect_path(id: "marco")
    assert_response :success
    assert_includes response.body, "🤷‍♂️ No Profile Found Here"
    assert_select ".pt-4 a.btn.btn-primary", text: "Browse Talks"
    assert_select ".pt-4 a.btn.btn-secondary", text: "View Events"
  end
end
