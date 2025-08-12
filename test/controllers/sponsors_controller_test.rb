require "test_helper"

class SponsorsControllerTest < ActionDispatch::IntegrationTest
  fixtures :sponsors, :event_sponsors

  test "should get index" do
    get sponsors_url
    assert_response :success
  end

  test "should get index with sponsors ordered by name" do
    get sponsors_url
    assert_response :success
    assert_equal sponsors(:two).name, assigns(:sponsors).first.name
    assert_equal sponsors(:one).name, assigns(:sponsors).last.name
  end

  test "should get index with letter" do
    get sponsors_url(letter: "a")
    assert_response :success
  end

  test "should get index featured events" do
    event_sponsor = event_sponsors(:one)
    event_sponsor.update(sponsor: sponsors(:one))
    event_sponsor.update(sponsor: sponsors(:two))
    get sponsors_url
    assert_response :success
    assert_equal event_sponsor.sponsor.name, assigns(:featured_sponsors).first.name
    assert_equal event_sponsor.sponsor.name, assigns(:featured_sponsors).last.name
  end

  test "should get show" do
    sponsor = sponsors(:one)
    get sponsor_url(sponsor)
    assert_response :success
  end
end
