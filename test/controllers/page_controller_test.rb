require "test_helper"

class PageControllerTest < ActionDispatch::IntegrationTest
  test "should get home page" do
    get root_path
    assert_response :success
  end

  test "should get uses page" do
    get uses_path
    assert_response :success
  end

  test "should set global meta tags" do
    get root_path
    assert_response :success

    assert_select "title", Metadata::DEFAULT_TITLE
    assert_select "meta[name=description][content=?]", Metadata::DEFAULT_DESC
    assert_select "link[rel='canonical'][href=?]", request.original_url

    expected_logo_url = @controller.view_context.image_url("logo_og_image.png")

    # OpenGraph
    assert_select "meta[property='og:title'][content=?]", Metadata::DEFAULT_TITLE
    assert_select "meta[property='og:description'][content=?]", Metadata::DEFAULT_DESC
    assert_select "meta[property='og:site_name'][content=?]", Metadata::SITE_NAME
    assert_select "meta[property='og:url'][content=?]", request.original_url
    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[property='og:image'][content=?]", expected_logo_url

    # Twitter
    assert_select "meta[name='twitter:title'][content=?]", Metadata::DEFAULT_TITLE
    assert_select "meta[name='twitter:description'][content=?]", Metadata::DEFAULT_DESC
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "meta[name='twitter:image'][content=?]", expected_logo_url
  end

  test "home page should render featured events" do
    events(:rails_world_2023).update!(
      featured_background: "#101820",
      featured_color: "#ffffff",
      home_sort_date: Date.today,
      recordings_published_date: Date.today
    )

    get root_path

    assert_response :success
    assert_select "section[aria-label=?]", "Featured Events"
  end

  test "home page features a happening event that has no talks (e.g. a camp/retreat)" do
    Event.create!(
      name: "Ruby Camp Test 2026",
      series: event_series(:rails_world),
      kind: "retreat",
      start_date: Date.today - 1,
      end_date: Date.today + 1,
      home_sort_date: Date.today,
      geocode_metadata: {},
      featured_background: "#E7F2E2",
      featured_color: "#064E3B"
    )

    get root_path

    assert_response :success
    assert_select "section[aria-label=?]", "Featured Events" do
      assert_select "a[aria-label=?]", "Ruby Camp Test 2026"
    end
  end

  test "home page does not feature events cancelled in event.yml" do
    cancelled_event, active_event = create_featured_events

    get root_path

    assert_response :success
    assert_select "section[aria-label=?]", "Featured Events" do
      assert_select "a[href=?]", event_path(active_event)
      assert_select "a[href=?]", event_path(cancelled_event), count: 0
    end
  end

  test "featured page does not include events cancelled in event.yml" do
    cancelled_event, active_event = create_featured_events

    get featured_path

    assert_response :success
    assert_select "a[href=?]", event_path(active_event)
    assert_select "a[href=?]", event_path(cancelled_event), count: 0
  end

  private

  def create_featured_events
    cancelled_slug = "xoruby-salt-lake-city-2026"

    assert_equal "cancelled", Static::Event.find_by_slug(cancelled_slug).status

    attributes = {
      series: event_series(:rails_world),
      kind: "conference",
      start_date: Date.today - 1,
      end_date: Date.today + 1,
      home_sort_date: Date.today,
      geocode_metadata: {}
    }

    cancelled_event = Event.create!(
      **attributes,
      name: "XO Ruby Salt Lake City 2026",
      slug: cancelled_slug,
      featured_background: "#230902",
      featured_color: "#FE470B"
    )

    active_event = Event.create!(
      **attributes,
      name: "Active Featured Event",
      slug: "active-featured-event",
      featured_background: "#E7F2E2",
      featured_color: "#064E3B"
    )

    [cancelled_event, active_event]
  end
end
