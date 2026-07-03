require "test_helper"

class Events::SponsorsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get event_sponsors_path(sponsors(:one).event)
    assert_response :success
  end

  test "should get index with sponsors ordered by tier" do
    event = sponsors(:one).event
    get event_sponsors_path(event)
    assert_response :success

    sponsors_by_tier = assigns(:sponsors_by_tier)

    assert_not_nil sponsors_by_tier, "sponsors_by_tier should not be nil"
    assert_equal sponsors(:one).organization.name, sponsors_by_tier["gold"].first.organization.name
    assert_equal sponsors(:two).organization.name, sponsors_by_tier["silver"].first.organization.name
    assert_equal sponsors(:three).organization.name, sponsors_by_tier["bronze"].first.organization.name
  end
end
