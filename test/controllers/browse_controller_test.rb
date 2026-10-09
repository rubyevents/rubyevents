require "test_helper"

class BrowseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "language rows are empty without spoken languages" do
    sign_in_as @user

    get browse_url("language_rows")

    assert_response :success
    assert_no_match "More Talks in", response.body
  end

  test "language rows recommend talks in the user's spoken languages" do
    @user.update!(language_preferences: {"pt" => {"understands" => true}})
    sign_in_as @user

    get browse_url("language_rows")

    assert_response :success
    assert_match "More Talks in", response.body
  end
end
