require "test_helper"

class Events::SeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event_series = event_series(:railsconf)
  end

  test "should get index" do
    get series_index_url
    assert_response :success
  end

  test "should show event series" do
    get series_url(@event_series)
    assert_response :success
  end

  test "should redirect to root for wrong slugs" do
    get series_url("wrong-slug")
    assert_response :moved_permanently
    assert_redirected_to root_path
  end

  test "should redirect to correct series slug when accessed via alias" do
    @event_series.aliases.create!(name: "Rails Conference", slug: "rails-conference")

    get series_url("rails-conference")
    assert_response :moved_permanently
    assert_redirected_to series_path(@event_series)
  end
end
