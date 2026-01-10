# frozen_string_literal: true

require "test_helper"

class Events::UpcomingEventBannerComponent::HelperMethodsTest < ViewComponent::TestCase
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
