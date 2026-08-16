require "test_helper"

class Events::ArchiveControllerTest < ActionDispatch::IntegrationTest
  setup do
    @conference = events(:brightonruby_2024)
    @meetup = events(:wnb_rb_meetup)
  end

  test "should get index with all filter" do
    get archive_events_path(kind: "all")
    assert_response :success
    assert_select "h1", /Events Archive/i
    assert_includes @response.body, @conference.name
    assert_includes @response.body, @meetup.name
  end

  test "should get index with meetup filter" do
    get archive_events_path(kind: "meetup")
    assert_response :success
    assert_includes @response.body, @meetup.name
    assert_not_includes @response.body, @conference.name
  end

  test "should get index with search results" do
    get archive_events_path(s: "brighton")
    assert_response :success
    assert_select "h1", /Events Archive/i
    assert_select "div", /search results for "brighton"/i
    assert_select "##{dom_id(@conference)}", 1
  end

  test "should get index and return events in the correct order" do
    event_names = %i[brightonruby_2024 no_sponsors_event new_rb_meetup railsconf_2017 railsconf_2025 rails_world_2023 tropical_rb_2024 future_conference rubyconfth_2022 wnb_rb_meetup].map { |event| events(event) }.map(&:name)

    get archive_events_path

    assert_response :success

    assert_select ".event .event-name", count: event_names.size do |nodes|
      assert_equal event_names, nodes.map(&:text)
    end
  end

  test "should get index search result" do
    get archive_events_path(letter: "T")
    assert_response :success
    assert_select "span", text: "Tropical Ruby 2024"
  end
end
