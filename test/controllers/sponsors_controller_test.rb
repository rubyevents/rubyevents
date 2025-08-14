require "test_helper"

class SponsorsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get sponsors_url
    assert_response :success
  end

  test "should get show" do
    sponsor = sponsors(:one)
    get sponsor_url(sponsor)
    assert_response :success
  end
end
