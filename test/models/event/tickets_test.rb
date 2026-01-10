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

  class TicketsUrlTest < ActiveSupport::TestCase
    class TestableTickets
      attr_accessor :url

      def tito?
        url&.match?(/ti\.to|tito\.io/)
      end

      def luma?
        url&.match?(/lu\.ma|luma\.com/)
      end

      def meetup?
        url&.include?("meetup.com")
      end

      def tito_event_slug
        return nil unless tito?
        match = url&.match(%r{(?:ti\.to|tito\.io)/(.+?)/?$})
        match&.captures&.first
      end

      def provider_name
        return "Tito" if tito?
        return "Luma" if luma?
        return "Meetup" if meetup?
        return "Connpass" if url&.include?("connpass.com")
        return "Pretix" if url&.include?("pretix")
        return "Eventpop" if url&.include?("eventpop")
        return "Eventbrite" if url&.include?("eventbrite")
        return "TicketTailor" if url&.include?("tickettailor")
        return "Sympla" if url&.include?("sympla.com")
        nil
      end
    end

    setup do
      @tickets = TestableTickets.new
    end

    test "tito? returns true for ti.to URL" do
      @tickets.url = "https://ti.to/goodscary/brightonruby-2024"
      assert @tickets.tito?
    end

    test "tito? returns true for tito.io URL" do
      @tickets.url = "https://tito.io/goodscary/brightonruby-2024"
      assert @tickets.tito?
    end

    test "tito? returns false for non-tito URL" do
      @tickets.url = "https://eventbrite.com/event/123"
      refute @tickets.tito?
    end

    test "luma? returns true for lu.ma URL" do
      @tickets.url = "https://lu.ma/my-event"
      assert @tickets.luma?
    end

    test "luma? returns false for non-luma URL" do
      @tickets.url = "https://ti.to/org/event"
      refute @tickets.luma?
    end

    test "meetup? returns true for meetup.com URL" do
      @tickets.url = "https://www.meetup.com/group/events/123"
      assert @tickets.meetup?
    end

    test "meetup? returns false for non-meetup URL" do
      @tickets.url = "https://ti.to/org/event"
      refute @tickets.meetup?
    end

    test "tito_event_slug extracts slug from ti.to URL" do
      @tickets.url = "https://ti.to/goodscary/brightonruby-2024"
      assert_equal "goodscary/brightonruby-2024", @tickets.tito_event_slug
    end

    test "tito_event_slug extracts slug from tito.io URL" do
      @tickets.url = "https://tito.io/goodscary/brightonruby-2024"
      assert_equal "goodscary/brightonruby-2024", @tickets.tito_event_slug
    end

    test "tito_event_slug returns nil for non-tito URL" do
      @tickets.url = "https://eventbrite.com/event/123"
      assert_nil @tickets.tito_event_slug
    end

    test "provider_name returns Tito for ti.to URLs" do
      @tickets.url = "https://ti.to/goodscary/brightonruby-2024"
      assert_equal "Tito", @tickets.provider_name
    end

    test "provider_name returns Luma for lu.ma URLs" do
      @tickets.url = "https://lu.ma/my-event"
      assert_equal "Luma", @tickets.provider_name
    end

    test "provider_name returns Meetup for meetup.com URLs" do
      @tickets.url = "https://www.meetup.com/group/events/123"
      assert_equal "Meetup", @tickets.provider_name
    end

    test "provider_name returns Eventbrite for eventbrite URLs" do
      @tickets.url = "https://www.eventbrite.com/e/123"
      assert_equal "Eventbrite", @tickets.provider_name
    end

    test "provider_name returns Pretix for pretix URLs" do
      @tickets.url = "https://pretix.eu/org/event"
      assert_equal "Pretix", @tickets.provider_name
    end

    test "provider_name returns nil for unknown URLs" do
      @tickets.url = "https://unknown-ticketing.com/event"
      assert_nil @tickets.provider_name
    end
  end
end
