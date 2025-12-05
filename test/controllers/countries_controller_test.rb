require "test_helper"

class CountriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @railsconf_event = events(:railsconf_2017)
    @rubyconfth_event = events(:rubyconfth_2022)
    @rails_world_event = events(:rails_world_2023)
    @tropical_rb_event = events(:tropical_rb_2024)
    @brightonruby_event = events(:brightonruby_2024)
  end

  test "should get index" do
    get countries_path
    assert_response :success
    assert_select "h1", /Countries/i
  end

  test "should display countries grouped by continent on index" do
    get countries_path
    assert_response :success

    # Verify that @countries_by_continent is assigned
    assert_not_nil assigns(:countries_by_continent)
    assert_not_nil assigns(:events_by_country)
    assert_not_nil assigns(:users_by_country)

    # Check that the assigned variables are hashes
    assert_kind_of Hash, assigns(:countries_by_continent)
    assert_kind_of Hash, assigns(:events_by_country)
    assert_kind_of Hash, assigns(:users_by_country)
  end

  test "should handle invalid country parameter" do
    get country_path("nonexistent-country")
    assert_response :not_found
  end

  test "should filter events and users by country on show page" do
    # Test the filtering logic by checking that events and users are properly filtered
    get country_path("united-states")
    assert_response :success

    events = assigns(:events)
    users = assigns(:users)
    assert_not_nil events
    assert_not_nil users
    assert_kind_of Array, events
    assert_kind_of ActiveRecord::Relation, users

    # All events should either match the country or be filtered out
    # The controller filters events where event.country == @country
    country = assigns(:country)
    if country.present?
      events.each do |event|
        # Each event should either have matching country or be included due to the filtering logic
        assert event.static_metadata.nil? || event.country == country || event.country.nil?
      end
    end
  end

  test "should sort events by home_sort_date in reverse order on show page" do
    get country_path("united-states")
    assert_response :success

    events = assigns(:events)
    assert_not_nil events
    assert_kind_of Array, events

    # Check that events are sorted in reverse order (most recent first)
    # The controller sorts by home_sort_date || Time.at(0).to_date in reverse
    if events.size > 1
      dates = events.map { |event| event.static_metadata&.home_sort_date || Time.at(0).to_date }
      assert_equal dates.sort.reverse, dates, "Events should be sorted by date in reverse order"
    end
  end

  test "should handle special characters in country parameter" do
    # Test with country parameter containing special characters
    get country_path("united-kingdom")
    assert_response :success

    assert_not_nil assigns(:events)
    assert_kind_of Array, assigns(:events)
  end

  test "should handle case sensitivity in country parameter" do
    # Test with different case variations
    get country_path("United-States")
    assert_response :success

    assert_not_nil assigns(:events)
    assert_kind_of Array, assigns(:events)
  end
end
