require "test_helper"

class Events::SponsorsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get event_sponsors_path(event_sponsors(:one).event)
    assert_response :success
  end

  test "should get index with sponsors ordered by tier" do
    event = event_sponsors(:one).event
    get event_sponsors_path(event)
    assert_response :success

    sponsors_by_tier = assigns(:sponsors_by_tier)
    assert_not_nil sponsors_by_tier, "sponsors_by_tier should not be nil"

    assert_equal event_sponsors(:one).sponsor.name, sponsors_by_tier["gold"].first.sponsor.name
    assert_equal event_sponsors(:two).sponsor.name, sponsors_by_tier["silver"].first.sponsor.name
    assert_equal event_sponsors(:three).sponsor.name, sponsors_by_tier["bronze"].first.sponsor.name
  end
end
