require "test_helper"

class Sponsors::MissingControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get sponsors_missing_index_url
    assert_response :success
  end
end
