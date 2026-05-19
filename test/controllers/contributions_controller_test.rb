require "test_helper"

class ContributionsControllerTest < ActionDispatch::IntegrationTest
  test "index returns success" do
    get contributions_path
    assert_response :success
  end
end
