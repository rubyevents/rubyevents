# frozen_string_literal: true

require "test_helper"

class Events::UpcomingEventBannerComponentTest < ViewComponent::TestCase
  setup do
    @past_event = events(:brightonruby_2024)
    @future_event = events(:future_conference)
    @series = event_series(:brightonruby)
  end

  test "does not render when event has no upcoming event with tickets in series" do
    render_inline(Events::UpcomingEventBannerComponent.new(event: @past_event))

    assert_no_selector "a"
  end

  test "does not render when event is not past" do
    render_inline(Events::UpcomingEventBannerComponent.new(event: @future_event))

    assert_no_selector "a"
  end

  test "component has render? method that checks for upcoming event" do
    component = Events::UpcomingEventBannerComponent.new(event: @past_event)

    refute component.render?
  end

  test "component accepts event option" do
    component = Events::UpcomingEventBannerComponent.new(event: @past_event)

    assert_equal @past_event, component.event
  end

  test "component accepts event_series option" do
    component = Events::UpcomingEventBannerComponent.new(event_series: @series)

    assert_equal @series, component.event_series
  end

  test "upcoming_event returns nil when event has no upcoming event with tickets" do
    component = Events::UpcomingEventBannerComponent.new(event: @past_event)

    assert_nil component.upcoming_event
  end

  test "upcoming_event returns nil when event_series has no upcoming event with tickets" do
    component = Events::UpcomingEventBannerComponent.new(event_series: @series)

    assert_nil component.upcoming_event
  end

  test "component with both event and event_series prefers event" do
    component = Events::UpcomingEventBannerComponent.new(event: @past_event, event_series: @series)

    assert_equal @past_event, component.event
  end
end
