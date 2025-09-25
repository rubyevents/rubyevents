require "test_helper"

class Profiles::ConnectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.connected_accounts.create(provider: "passport", uid: "123456")

    @lazaro = users(:lazaro_nixon)
    @lazaro.connected_accounts.create(provider: "passport", uid: "ABCDEF")
  end

  test "should redirect to root path" do
    get profiles_connect_index_path
    assert_redirected_to root_path
  end

  test "guest should see the claim profile page" do
    get profiles_connect_path(id: "marco")
    assert_response :success
    assert_includes response.body, "is available to Claim!"
    assert_select ".pt-4 a.btn.btn-primary[data-turbo-frame='modal']", text: "Claim my Passport"
  end

  # for now this feature is disabled
  # test "guest should see the friend prompt page" do
  #   get profiles_connect_path(id: "one")
  #   assert_response :success
  #   assert_includes response.body, "🎉 Awesome! You Discovered a Friend"
  #   assert_includes response.body, "Sign In and Connect"
  # end

  # test "user should see the friend prompt page" do
  #   sign_in_as @lazaro
  #   get profiles_connect_path(id: "one")
  #   assert_response :success
  #   assert_includes response.body, "🎉 Awesome! You Discovered a Friend"
  #   # enable this when we have a way to connect to other users
  #   # assert_select ".pt-4 a.btn.btn-primary.btn-disabled.hidden", text: "Connect"
  # end

  test "guest visiting a claimed profile should be redirected to the claimed profile page" do
    get profiles_connect_path(id: @user.passports.first.uid)
    assert_redirected_to profile_path(@user)
  end

  # test "user should see no profile found page" do
  #   sign_in_as @lazaro
  #   get profiles_connect_path(id: "123457")
  #   assert_response :success
  #   assert_includes response.body, "🤷‍♂️ No Profile Found Here"
  #   assert_select ".pt-4 a.btn.btn-primary", text: "Browse Talks"
  #   assert_select ".pt-4 a.btn.btn-secondary", text: "View Events"
  # end

  test "user should get redirected if they land on their connect page" do
    sign_in_as @lazaro
    get profiles_connect_path(id: "ABCDEF")
    assert_redirected_to profile_path(@lazaro)
    assert_equal "You did it. You landed on your profile page 🙌", flash[:notice]
  end

  test "user should be able to claim a profile" do
    sign_in_as users(:admin)
    get profiles_connect_path(id: "not_a_user")
    assert_includes response.body, "is available to Claim!"
    # This is a POST request to claim a profile for themselves
    assert_select ".pt-4 a.btn.btn-primary[data-turbo-method=\"post\"]"
  end
end
