# frozen_string_literal: true

require "test_helper"

class Tito::ButtonComponentTest < ViewComponent::TestCase
  setup do
    @past_event = events(:brightonruby_2024)
    @future_event = events(:future_conference)
  end

  test "does not render when tickets are not available" do
    render_inline(Tito::ButtonComponent.new(event: @past_event))

    assert_no_text "Tickets"
  end

  test "does not render for past events" do
    render_inline(Tito::ButtonComponent.new(event: @past_event))

    assert_no_text "Tickets"
  end

  test "does not render for future events without tickets" do
    render_inline(Tito::ButtonComponent.new(event: @future_event))

    assert_no_text "Tickets"
  end

  test "component has correct classes method" do
    component = Tito::ButtonComponent.new(event: @past_event)

    assert_equal "btn btn-primary btn-sm w-full no-animation", component.classes
  end

  test "component has default label" do
    component = Tito::ButtonComponent.new(event: @past_event)

    assert_equal "Tickets", component.label
  end

  test "component accepts custom label" do
    component = Tito::ButtonComponent.new(event: @past_event, label: "Get Your Tickets")

    assert_equal "Get Your Tickets", component.label
  end
end
