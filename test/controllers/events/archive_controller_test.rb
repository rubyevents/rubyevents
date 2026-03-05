require "test_helper"

class Events::ArchiveControllerTest < ActionDispatch::IntegrationTest
  setup do
    @conference = events(:brightonruby_2024)
    @meetup = events(:wnb_rb_meetup)
  end

  test "should get index with all filter" do
    get archive_events_path(kind: "all")
    assert_response :success
    assert_includes @response.body, @conference.name
    assert_includes @response.body, @meetup.name
  end

  test "should get index with meetup filter" do
    get archive_events_path(kind: "meetup")
    assert_response :success
    assert_includes @response.body, @meetup.name
    assert_not_includes @response.body, @conference.name
  end
end
