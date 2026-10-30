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

  test "should show a meetup group with its upcoming and past meetups" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
    Event.create!(name: "Test.rb Meetup January 2020", slug: "testrb-2020-01-14", series: series, kind: :meetup, start_date: "2020-01-14", end_date: "2020-01-14")
    upcoming = Event.create!(name: "Test.rb Meetup January 2099", slug: "testrb-2099-01-14", series: series, kind: :meetup, start_date: "2099-01-14", end_date: "2099-01-14")

    get series_url(series)

    assert_response :success
    assert_select "nav[aria-label=?] a[aria-current=page]", "Upcoming or past meetups", text: "Upcoming (1)"
    assert_select "#meetups a[href=?]", event_path(upcoming), text: upcoming.name

    get series_url(series, view: "past")

    assert_response :success
    assert_select "nav[aria-label=?] a[aria-current=page]", "Upcoming or past meetups", text: "Past (1)"
    assert_select "#meetups h3", text: "Test.rb Meetup January 2020"
  end

  test "should show whether the user follows a meetup group" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
    Event.create!(name: "Test.rb Meetup January 2099", slug: "testrb-2099-01-14", series: series, kind: :meetup, start_date: "2099-01-14", end_date: "2099-01-14")
    user = sign_in_as(users(:one))

    get series_url(series)

    assert_select ".follow_button", text: /Follow Series/

    user.event_series_subscriptions.create!(event_series: series)
    get series_url(series)

    assert_select ".follow_button", text: /Following/
  end

  test "should list all past meetups of a group on its events page" do
    series = EventSeries.create!(name: "Test.rb", slug: "testrb", kind: :meetup)
    meetups = (1..25).map { |month| Event.create!(name: "Test.rb #{month}", slug: "testrb-2020-#{month}", series: series, kind: :meetup, start_date: Date.new(2018, 1, 1) + (month * 30), end_date: Date.new(2018, 1, 1) + (month * 30)) }

    get events_series_url(series)

    assert_response :success
    assert_select "nav[aria-label=?] a[aria-current=page]", "Upcoming or past meetups", text: "Past (25)"
    assert_select "#meetups article", 25
    assert_select "#meetups a[href=?]", event_path(meetups.first)
  end

  test "should redirect the events page of a series without meetups to the series" do
    get events_series_url(@event_series)

    assert_redirected_to series_path(@event_series)
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
