require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  setup do
    @event = events(:railsconf_2017)
  end

  def globe_state(expression)
    page.evaluate_script(<<~JS)
      (() => {
        const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("#events-globe"), "globe")
        return #{expression}
      })()
    JS
  end

  def skip_without_webgl
    skip "WebGL is not available in this browser" unless page.evaluate_script("!!document.createElement('canvas').getContext('webgl')")
  end

  test "visiting the index" do
    events(:tropical_rb_2024)
    visit root_url

    click_on "Events"
    assert_selector "h1", text: "Upcoming Events"

    click_on "Archive"
    assert_selector "h1", text: "Events Archive"

    click_on "T", exact_text: true
    assert_selector "span", text: "Tropical Ruby"
  end

  test "hovering an upcoming event switches the globe caption" do
    europe = events(:rails_world_2023)
    north_america = events(:railsconf_2025)
    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now)
    north_america.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now)

    visit events_url

    assert_selector "#events-globe"

    find("#event-list .event-item[data-event-id='#{north_america.slug}']").hover

    assert_selector "#events-globe a[data-event-id='#{north_america.slug}']", text: north_america.name
    assert_selector "#events-globe a[data-event-list-target=caption]", count: 1
  end

  test "clicking a marker on the globe selects its event" do
    europe = events(:rails_world_2023)
    north_america = events(:railsconf_2025)
    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now, latitude: 52.37, longitude: 4.9)
    north_america.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now, latitude: 30.27, longitude: -97.74)

    visit events_url
    skip_without_webgl

    # Hovering the list rotates the globe towards the event, which brings its marker round to the front
    find("#event-list .event-item[data-event-id='#{europe.slug}']").hover
    find("#events-globe [data-globe-target=marker] img[data-slug='#{europe.slug}']").click

    assert globe_state("controller.following"), "expected the globe to follow the selected event"
    assert_selector "#events-globe a[data-event-id='#{europe.slug}']", text: europe.name
    assert_selector "#events-globe a[data-event-list-target=caption]", count: 1
  end

  test "filtering by continent morphs the page and keeps the globe canvas" do
    europe = events(:rails_world_2023)
    north_america = events(:railsconf_2025)
    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now, latitude: 52.37, longitude: 4.9)
    north_america.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now, latitude: 30.27, longitude: -97.74)

    visit events_url

    assert_selector "#events-globe [data-globe-target=marker]", count: 2, visible: :all
    page.execute_script(%(document.querySelector("#events-globe canvas").dataset.probe = "kept"))

    within "nav[aria-label='Filter events by continent']" do
      click_on "Europe"
    end

    assert_selector "#event-list", text: europe.name
    assert_no_selector "#event-list", text: north_america.name
    assert_selector "#events-globe [data-globe-target=marker]", count: 1, visible: :all
    assert_equal "kept", find("#events-globe canvas", visible: :all)["data-probe"]
    assert_selector "#events-globe[data-globe-center-value^='[5']"
  end

  test "filtering by continent zooms the globe in and resetting zooms it back out" do
    europe = events(:rails_world_2023)
    north_america = events(:railsconf_2025)
    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now, latitude: 52.37, longitude: 4.9)
    north_america.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now, latitude: 30.27, longitude: -97.74)

    visit events_url(continent: "europe")

    assert_selector "#event-list", text: europe.name
    assert_in_delta 1.4, globe_state("controller.zoom"), 0.01

    within "nav[aria-label='Filter events by continent']" do
      click_on "All"
    end

    assert_selector "#event-list", text: north_america.name
    assert_nil globe_state("controller.center")
    sleep 2
    assert_in_delta 1, globe_state("controller.zoom"), 0.05
  end

  test "morphing the page keeps the markers on their locations" do
    europe = events(:rails_world_2023)
    europe.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now, latitude: 52.37, longitude: 4.9)

    visit events_url
    skip_without_webgl

    find("#event-list .event-item[data-event-id='#{europe.slug}']").hover
    assert_selector "#events-globe [data-globe-target=marker] img[data-slug='#{europe.slug}']"

    # The morph strips this attribute, which tells us when the marker elements have been reset
    page.execute_script(%(document.querySelector("#events-globe [data-globe-target=marker]").dataset.probe = "stale"))

    within "nav[aria-label='Filter events by continent']" do
      click_on "All"
    end

    assert_no_selector "#events-globe [data-globe-target=marker][data-probe]", visible: :all
    assert_selector "#events-globe [data-globe-target=marker] img[data-slug='#{europe.slug}']"
  end

  test "markers of nearby events fan out so both stay visible" do
    amsterdam = events(:rails_world_2023)
    utrecht = events(:railsconf_2025)
    amsterdam.update!(start_date: 1.week.from_now, end_date: 1.week.from_now, date: 1.week.from_now, latitude: 52.37, longitude: 4.9)
    utrecht.update!(start_date: 2.weeks.from_now, end_date: 2.weeks.from_now, date: 2.weeks.from_now, latitude: 52.09, longitude: 5.12)

    visit events_url
    skip_without_webgl

    find("#event-list .event-item[data-event-id='#{amsterdam.slug}']").hover
    assert_selector "#events-globe [data-globe-target=marker] img[data-slug='#{utrecht.slug}']"

    distance = page.evaluate_script(<<~JS)
      (() => {
        const centers = ["#{amsterdam.slug}", "#{utrecht.slug}"].map((slug) => {
          const rect = document.querySelector(`#events-globe img[data-slug='${slug}']`).closest("[data-globe-target=marker]").getBoundingClientRect()
          return [rect.x + rect.width / 2, rect.y + rect.height / 2]
        })
        return Math.hypot(centers[0][0] - centers[1][0], centers[0][1] - centers[1][1])
      })()
    JS

    assert_operator distance, :>=, 20, "expected the two markers to be pushed apart"
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
