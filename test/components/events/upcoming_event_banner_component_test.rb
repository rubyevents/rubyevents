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

  class HelperMethodsTest < ViewComponent::TestCase
    class TestableComponent < Events::UpcomingEventBannerComponent
      attr_writer :test_upcoming_event

      def upcoming_event
        @test_upcoming_event
      end
    end

    setup do
      @event = events(:brightonruby_2024)
    end

    test "background_style returns featured_background for solid color" do
      static_metadata = Struct.new(:featured_background, :featured_color).new("#cc342d", "white")
      mock_event = Struct.new(:static_metadata).new(static_metadata)

      component = TestableComponent.new(event: @event)
      component.test_upcoming_event = mock_event

      assert_equal "#cc342d", component.background_style
    end

    test "background_style returns url format for data URLs" do
      static_metadata = Struct.new(:featured_background, :featured_color).new("data:image/png;base64,abc123", "white")
      mock_event = Struct.new(:static_metadata).new(static_metadata)

      component = TestableComponent.new(event: @event)
      component.test_upcoming_event = mock_event

      assert_match(/url\('data:image\/png;base64,abc123'\)/, component.background_style)
    end

    test "background_color returns color for solid color" do
      static_metadata = Struct.new(:featured_background, :featured_color).new("#cc342d", "white")
      mock_event = Struct.new(:static_metadata).new(static_metadata)

      component = TestableComponent.new(event: @event)
      component.test_upcoming_event = mock_event

      assert_equal "#cc342d", component.background_color
    end

    test "background_color returns black for data URLs" do
      static_metadata = Struct.new(:featured_background, :featured_color).new("data:image/png;base64,abc123", "white")
      mock_event = Struct.new(:static_metadata).new(static_metadata)

      component = TestableComponent.new(event: @event)
      component.test_upcoming_event = mock_event

      assert_equal "#000000", component.background_color
    end

    test "text_color returns featured_color" do
      static_metadata = Struct.new(:featured_background, :featured_color).new("#cc342d", "white")
      mock_event = Struct.new(:static_metadata).new(static_metadata)

      component = TestableComponent.new(event: @event)
      component.test_upcoming_event = mock_event

      assert_equal "white", component.text_color
    end
  end
end
