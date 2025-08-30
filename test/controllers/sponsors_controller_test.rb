require "test_helper"

class SponsorsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get sponsors_url
    assert_response :success
  end

  test "should get index with sponsors ordered by name" do
    get sponsors_url
    assert_response :success
    ordered_sponsors = Sponsor.order(:name)
    assert_equal ordered_sponsors.to_a, assigns(:sponsors).to_a
  end

  test "should get index with letter" do
    get sponsors_url(letter: "a")
    assert_response :success
  end

  test "should get index featured events" do
    sponsor = sponsors(:one)
    event1 = events(:railsconf_2017)
    event2 = events(:rubyconfth_2022)
    event1_sponsor = sponsor.event_sponsors.create(event: event1, tier: "gold")
    event2_sponsor = sponsor.event_sponsors.create(event: event2, tier: "silver")
    get sponsors_url
    assert_response :success
    assert_includes assigns(:featured_sponsors), event1_sponsor.sponsor
    assert_includes assigns(:featured_sponsors), event2_sponsor.sponsor
  end

  test "should get show" do
    sponsor = sponsors(:one)
    get sponsor_url(sponsor)
    assert_response :success
  end
end
