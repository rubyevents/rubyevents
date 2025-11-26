require "test_helper"

class SponsorTest < ActiveSupport::TestCase
  def setup
    @event = events(:railsconf_2017)
    @organization = organizations(:one)
  end

  test "allows same organization for same event with different tiers" do
    Sponsor.create!(event: @event, organization: @organization, tier: "gold")

    assert_nothing_raised do
      Sponsor.create!(event: @event, organization: @organization, tier: "silver")
    end
  end

  test "prevents duplicate organization for same event and tier" do
    Sponsor.create!(event: @event, organization: @organization, tier: "gold")

    duplicate = Sponsor.new(event: @event, organization: @organization, tier: "gold")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:organization_id],
      "is already associated with this event for the same tier"
  end

  test "allows same organization for different events with same tier" do
    other_event = events(:rubyconfth_2022)

    Sponsor.create!(event: @event, organization: @organization, tier: "gold")

    assert_nothing_raised do
      Sponsor.create!(event: other_event, organization: @organization, tier: "gold")
    end
  end

  test "handles nil tiers correctly" do
    Sponsor.create!(event: @event, organization: @organization, tier: nil)

    duplicate = Sponsor.new(event: @event, organization: @organization, tier: nil)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:organization_id],
      "is already associated with this event for the same tier"
  end

  test "treats empty string tier as nil" do
    Sponsor.create!(event: @event, organization: @organization, tier: "")

    duplicate = Sponsor.new(event: @event, organization: @organization, tier: nil)

    assert_not duplicate.valid?
  end
end
