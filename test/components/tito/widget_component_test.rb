# frozen_string_literal: true

require "test_helper"

class Tito::WidgetComponentTest < ViewComponent::TestCase
  setup do
    @past_event = events(:brightonruby_2024)
    @future_event = events(:future_conference)
  end

  test "does not render when event is past" do
    render_inline(Tito::WidgetComponent.new(event: @past_event))

    assert_no_selector "tito-widget"
  end

  test "does not render for future events without tito tickets" do
    render_inline(Tito::WidgetComponent.new(event: @future_event))

    assert_no_selector "tito-widget"
  end

  test "component has wrapper option defaulting to true" do
    component = Tito::WidgetComponent.new(event: @past_event)

    assert component.wrapper
  end

  test "component accepts wrapper false option" do
    component = Tito::WidgetComponent.new(event: @past_event, wrapper: false)

    refute component.wrapper
  end

  test "event_slug delegates to tickets.tito_event_slug" do
    component = Tito::WidgetComponent.new(event: @past_event)

    assert_nil component.event_slug
  end
end
