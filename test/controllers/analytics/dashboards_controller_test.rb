require "test_helper"

class Analytics::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get analytics_dashboards_path
    assert_response :success
  end

  test "only return the last 60 days of data excluding today" do
    travel_to Time.new(2023, 8, 26, 12, 0, 0) do
      visit_1 = Ahoy::Visit.create!(started_at: Time.current)
      Ahoy::Event.create!(name: "Some Page during visit_1", visit: visit_1, time: Time.current)
      Recurring::RollupJob.new.perform
    end

    travel_to Time.new(2023, 8, 27, 12, 0, 0) do
      visit_2 = Ahoy::Visit.create!(started_at: Time.current)
      Ahoy::Event.create!(name: "Some Page during visit_2", visit: visit_2, time: Time.current)
      Recurring::RollupJob.new.perform
      get daily_page_views_analytics_dashboards_path
      assert_response :success
      yesterday_page_views = assigns(:daily_page_views)[Date.new(2023, 8, 26)]
      today_page_views = assigns(:daily_page_views)[Date.new(2023, 8, 27)]
      assert_equal 1, yesterday_page_views
      assert_nil today_page_views
    end
  end

  test "should aggregate daily_visits with rollup" do
    travel_to Time.new(2023, 8, 26, 12, 0, 0) do
      visit_1 = Ahoy::Visit.create!(started_at: Time.current)
      Ahoy::Event.create!(name: "Some Page during visit_1", visit: visit_1, time: Time.current)
      Recurring::RollupJob.new.perform
    end

    # Travel to a fixed time for a consistent test environment
    travel_to Time.new(2023, 8, 27, 12, 0, 0) do
      # Make first call to populate cache
      get daily_visits_analytics_dashboards_path
      assert_response :success

      yesterday_page_views = assigns(:daily_visits)[Date.new(2023, 8, 26)]
      today_page_views = assigns(:daily_visits)[Date.new(2023, 8, 27)]
      assert_equal 1, yesterday_page_views
      assert_nil today_page_views

      # Create a new page view today
      visit_2 = Ahoy::Visit.create!(started_at: Time.current)
      Ahoy::Event.create!(name: "Some Page during visit 2", visit: visit_2, time: Time.current)

      Recurring::RollupJob.new.perform

      # Make second call, length should not change because we only display the last 60 days up to yesterday
      get daily_visits_analytics_dashboards_path
      assert_response :success
      yesterday_page_views = assigns(:daily_visits)[Date.new(2023, 8, 26)]
      today_page_views = assigns(:daily_visits)[Date.new(2023, 8, 27)]
      assert_equal 1, yesterday_page_views
      assert_nil today_page_views
    end

    # Travel to the next morning, cache should expire
    travel_to Time.new(2023, 8, 28, 12, 0, 0) do
      # Make third call, length should change by 1
      get daily_visits_analytics_dashboards_path
      assert_response :success
      day_before_yesterday_page_views = assigns(:daily_visits)[Date.new(2023, 8, 27)]
      yesterday_page_views = assigns(:daily_visits)[Date.new(2023, 8, 27)]
      today_page_views = assigns(:daily_visits)[Date.new(2023, 8, 28)]
      assert_equal 1, day_before_yesterday_page_views
      assert_equal 1, yesterday_page_views
      assert_nil today_page_views
    end
  end
end
