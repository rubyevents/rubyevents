require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup do
    @event = events(:railsconf_2017)
  end

  test "visiting the index" do
    events(:tropical_rb_2024)
    visit root_url

    click_on "Events"
    assert_selector "h1", text: "Upcoming Events"

    click_on "Archive"
    assert_selector "h1", text: "Events Archive"

    find("a#t", text: "T").click
    assert_selector "span", text: "Tropical Ruby"
  end

  test "filtering upcoming events by continent" do
    europe = events(:rails_world_2023)
    north_america = events(:railsconf_2025)
    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now)
    north_america.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now)

    visit events_url

    assert_selector "#event-list", text: europe.name
    assert_selector "#event-list", text: north_america.name

    within "nav[aria-label='Filter events by continent']" do
      click_on "Europe"
    end

    assert_selector "#event-list", text: europe.name
    assert_no_selector "#event-list", text: north_america.name

    within "nav[aria-label='Filter events by continent']" do
      click_on "Africa"
    end

    assert_selector "h2", text: "No events found"

    click_on "Show all events"

    assert_selector "#event-list", text: europe.name
    assert_selector "#event-list", text: north_america.name
  end

  test "visiting the show" do
    visit event_url(@event)
    assert_selector "h1", text: @event.name
  end

  # Currently this test fails for 2 reasons:
  # 1. The "Edit this event" button is on events_url
  # 2. 'Description', 'Frequency', 'Kind' and 'Website' are attributes of the event's organisation, not the even itself
  # The update method and the form would need to be amended for the method to work
  # test "should update Event" do
  #   visit event_url(@event)
  #   click_on "Edit this event", match: :first

  #   fill_in "Description", with: @event.description
  #   fill_in "Frequency", with: @event.frequency
  #   fill_in "Kind", with: @event.kind
  #   fill_in "Name", with: @event.name
  #   fill_in "Website", with: @event.website
  #   click_on "Update Event"

  #   assert_text "Event was successfully updated"
  #   click_on "Back"
  # end
end
