# frozen_string_literal: true

require "test_helper"

class Event::TicketsTest < ActiveSupport::TestCase
  setup do
    @event = events(:brightonruby_2024)
    @future_event = events(:future_conference)
  end

  test "exist? returns false when no tickets_url is set" do
    refute @event.tickets.exist?
  end

  test "available? returns false when no tickets_url is set" do
    refute @event.tickets.available?
  end

  test "url returns nil when no tickets_url is set" do
    assert_nil @event.tickets.url
  end

  test "tito? returns false when url is nil" do
    refute @event.tickets.tito?
  end

  test "luma? returns false when url is nil" do
    refute @event.tickets.luma?
  end

  test "meetup? returns false when url is nil" do
    refute @event.tickets.meetup?
  end

  test "tito_event_slug returns nil when url is nil" do
    assert_nil @event.tickets.tito_event_slug
  end

  test "provider_name returns nil when url is nil" do
    assert_nil @event.tickets.provider_name
  end

  test "event.tickets? returns false when no tickets exist" do
    refute @event.tickets?
  end

  test "event.next_upcoming_event_with_tickets returns nil when series is nil" do
    event = Event.new(name: "Test")
    assert_nil event.next_upcoming_event_with_tickets
  end

  test "event.next_upcoming_event_with_tickets returns nil when no upcoming events with tickets" do
    assert_nil @event.next_upcoming_event_with_tickets
  end
end
