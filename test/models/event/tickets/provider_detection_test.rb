# frozen_string_literal: true

require "test_helper"

class Event::Tickets::ProviderDetectionTest < ActiveSupport::TestCase
  def tickets_for(url)
    event = events(:brightonruby_2024)
    tickets = Event::Tickets.new(event: event)
    tickets.define_singleton_method(:url) { url }
    tickets
  end

  test "tito? returns true for ti.to URL" do
    assert tickets_for("https://ti.to/goodscary/brightonruby-2024").tito?
  end

  test "tito? returns true for tito.io URL" do
    assert tickets_for("https://tito.io/goodscary/brightonruby-2024").tito?
  end

  test "tito? returns false for non-tito URL" do
    refute tickets_for("https://eventbrite.com/event/123").tito?
  end

  test "luma? returns true for lu.ma URL" do
    assert tickets_for("https://lu.ma/my-event").luma?
  end

  test "luma? returns false for non-luma URL" do
    refute tickets_for("https://ti.to/org/event").luma?
  end

  test "meetup? returns true for meetup.com URL" do
    assert tickets_for("https://www.meetup.com/group/events/123").meetup?
  end

  test "meetup? returns false for non-meetup URL" do
    refute tickets_for("https://ti.to/org/event").meetup?
  end

  test "tito_event_slug extracts slug from ti.to URL" do
    assert_equal "goodscary/brightonruby-2024", tickets_for("https://ti.to/goodscary/brightonruby-2024").tito_event_slug
  end

  test "tito_event_slug extracts slug from tito.io URL" do
    assert_equal "goodscary/brightonruby-2024", tickets_for("https://tito.io/goodscary/brightonruby-2024").tito_event_slug
  end

  test "tito_event_slug returns nil for non-tito URL" do
    assert_nil tickets_for("https://eventbrite.com/event/123").tito_event_slug
  end

  test "provider_name returns Tito for ti.to URLs" do
    assert_equal "Tito", tickets_for("https://ti.to/goodscary/brightonruby-2024").provider_name
  end

  test "provider_name returns Luma for lu.ma URLs" do
    assert_equal "Luma", tickets_for("https://lu.ma/my-event").provider_name
  end

  test "provider_name returns Meetup for meetup.com URLs" do
    assert_equal "Meetup", tickets_for("https://www.meetup.com/group/events/123").provider_name
  end

  test "provider_name returns Eventbrite for eventbrite URLs" do
    assert_equal "Eventbrite", tickets_for("https://www.eventbrite.com/e/123").provider_name
  end

  test "provider_name returns Pretix for pretix URLs" do
    assert_equal "Pretix", tickets_for("https://pretix.eu/org/event").provider_name
  end

  test "provider_name returns nil for unknown URLs" do
    assert_nil tickets_for("https://unknown-ticketing.com/event").provider_name
  end

  test "tito? returns false when ti.to appears in path only" do
    refute tickets_for("https://example.com/redirect?url=ti.to/event").tito?
  end

  test "luma? returns false when lu.ma appears in path only" do
    refute tickets_for("https://example.com/events/lu.ma-style").luma?
  end

  test "meetup? returns false when meetup.com appears in query string" do
    refute tickets_for("https://example.com/redirect?to=meetup.com/group").meetup?
  end

  test "provider_name returns nil when eventbrite appears in path" do
    assert_nil tickets_for("https://example.com/compare-to-eventbrite").provider_name
  end

  test "provider_name handles invalid URLs gracefully" do
    assert_nil tickets_for("not a valid url at all").provider_name
  end

  test "provider_name handles empty URL" do
    assert_nil tickets_for("").provider_name
  end

  test "provider_name handles nil URL" do
    assert_nil tickets_for(nil).provider_name
  end

  test "tito? works with www subdomain" do
    assert tickets_for("https://www.ti.to/goodscary/brightonruby-2024").tito?
  end

  test "meetup? works with www subdomain" do
    assert tickets_for("https://www.meetup.com/ruby-group/events/123").meetup?
  end

  test "provider_name returns Connpass for connpass.com URLs" do
    assert_equal "Connpass", tickets_for("https://connpass.com/event/123").provider_name
  end

  test "provider_name returns Sympla for sympla.com.br URLs" do
    assert_equal "Sympla", tickets_for("https://www.sympla.com.br/evento/123").provider_name
  end

  test "provider_name returns Sympla for sympla.com.br without subdomain" do
    assert_equal "Sympla", tickets_for("https://sympla.com.br/evento/123").provider_name
  end

  test "provider_name returns TicketTailor for tickettailor URLs" do
    assert_equal "TicketTailor", tickets_for("https://www.tickettailor.com/events/org/123").provider_name
  end

  test "provider_name returns Eventpop for eventpop.me URLs" do
    assert_equal "Eventpop", tickets_for("https://www.eventpop.me/e/123").provider_name
  end

  test "provider returns a StringInquirer" do
    assert_kind_of ActiveSupport::StringInquirer, tickets_for("https://ti.to/org/event").provider
  end

  test "provider.tito? returns true for tito URLs" do
    assert tickets_for("https://ti.to/org/event").provider.tito?
  end

  test "provider.luma? returns true for luma URLs" do
    assert tickets_for("https://lu.ma/my-event").provider.luma?
  end

  test "provider.meetup? returns true for meetup URLs" do
    assert tickets_for("https://meetup.com/group/events/123").provider.meetup?
  end

  test "provider.eventbrite? returns true for eventbrite URLs" do
    assert tickets_for("https://eventbrite.com/e/123").provider.eventbrite?
  end

  test "provider.tito? returns false for non-tito URLs" do
    refute tickets_for("https://lu.ma/my-event").provider.tito?
  end

  test "provider inquiry returns false for unknown provider" do
    tickets = tickets_for("https://unknown.com/event")
    refute tickets.provider.tito?
    refute tickets.provider.luma?
    refute tickets.provider.unknown?
  end

  test "provider equals empty string for unknown URLs" do
    assert_equal "", tickets_for("https://unknown.com/event").provider
  end

  test "provider equals provider name downcased" do
    assert_equal "tito", tickets_for("https://ti.to/org/event").provider
  end
end
