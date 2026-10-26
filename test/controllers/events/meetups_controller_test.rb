require "test_helper"

class Events::MeetupsControllerTest < ActionDispatch::IntegrationTest
  test "should show meetup groups" do
    series = EventSeries.create!(name: "Geneva.rb", slug: "geneva-rb", kind: :meetup)
    Event.create!(name: "Geneva.rb Meetup January 2026", slug: "geneva-rb-2026-01-14", kind: :meetup, series: series, start_date: "2026-01-14", end_date: "2026-01-14")

    get meetups_events_url
    assert_response :success
    assert_match "Geneva.rb", response.body
    assert_match "Last meetup", response.body
  end

  test "should mark meetup groups of an ended series as inactive" do
    series = EventSeries.create!(name: "Triangle.rb", slug: "triangle-rb", kind: :meetup)
    static_series = Static::EventSeries.new(id: "triangle-rb", name: "Triangle.rb", kind: "meetup", ended: true)

    Static::EventSeries.stub(:find_by_slug, ->(slug) { static_series if slug == "triangle-rb" }) do
      get meetups_events_url
    end

    assert_response :success
    assert_match series.name, response.body
    assert_match "Inactive", response.body
  end
end
