require "test_helper"

class EventSponsorTest < ActiveSupport::TestCase
  def setup
    @event = events(:railsconf_2017)
    @sponsor = sponsors(:one)
  end

  test "allows same sponsor for same event with different tiers" do
    EventSponsor.create!(event: @event, sponsor: @sponsor, tier: "gold")

    assert_nothing_raised do
      EventSponsor.create!(event: @event, sponsor: @sponsor, tier: "silver")
    end
  end

  test "prevents duplicate sponsor for same event and tier" do
    EventSponsor.create!(event: @event, sponsor: @sponsor, tier: "gold")

    duplicate = EventSponsor.new(event: @event, sponsor: @sponsor, tier: "gold")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sponsor_id],
      "is already associated with this event for the same tier"
  end

  test "allows same sponsor for different events with same tier" do
    other_event = events(:rubyconfth_2022)

    EventSponsor.create!(event: @event, sponsor: @sponsor, tier: "gold")

    assert_nothing_raised do
      EventSponsor.create!(event: other_event, sponsor: @sponsor, tier: "gold")
    end
  end

  test "handles nil tiers correctly" do
    EventSponsor.create!(event: @event, sponsor: @sponsor, tier: nil)

    duplicate = EventSponsor.new(event: @event, sponsor: @sponsor, tier: nil)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sponsor_id],
      "is already associated with this event for the same tier"
  end

  test "treats empty string tier as nil" do
    EventSponsor.create!(event: @event, sponsor: @sponsor, tier: "")

    duplicate = EventSponsor.new(event: @event, sponsor: @sponsor, tier: nil)

    assert_not duplicate.valid?
  end
end
