require "test_helper"

class SponsorTest < ActiveSupport::TestCase
  def setup
    @event = events(:railsconf_2017)
    @other_event = events(:rubyconfth_2022)
    @organization = organizations(:one)
    @other_organization = organizations(:two)
  end

  test "allows same organization for same event with different tiers" do
    assert_nothing_raised do
      Sponsor.create!(event: @event, organization: @organization, tier: "platinum")
    end
  end

  test "prevents duplicate organization for same event and tier" do
    duplicate = Sponsor.new(event: @event, organization: @organization, tier: "gold")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:organization_id], "is already associated with this event for the same tier"
  end

  test "allows same organization for different events with same tier" do
    Sponsor.create!(event: @event, organization: @other_organization, tier: "diamond")

    assert_nothing_raised do
      Sponsor.create!(event: @other_event, organization: @other_organization, tier: "diamond")
    end
  end

  test "handles nil tiers correctly" do
    org = Organization.create!(name: "Nil Tier Test Org")
    Sponsor.create!(event: @event, organization: org, tier: nil)

    duplicate = Sponsor.new(event: @event, organization: org, tier: nil)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:organization_id],
      "is already associated with this event for the same tier"
  end

  test "treats empty string tier as nil" do
    org = Organization.create!(name: "Empty Tier Test Org")
    Sponsor.create!(event: @event, organization: org, tier: "")

    duplicate = Sponsor.new(event: @event, organization: org, tier: nil)

    assert_not duplicate.valid?
  end

  test "belongs to event" do
    sponsor = sponsors(:one)
    assert_instance_of Event, sponsor.event
  end

  test "belongs to organization" do
    sponsor = sponsors(:one)
    assert_instance_of Organization, sponsor.organization
  end

  test "requires event" do
    sponsor = Sponsor.new(organization: @organization, tier: "gold")
    assert_not sponsor.valid?
    assert_includes sponsor.errors[:event], "must exist"
  end

  test "requires organization" do
    sponsor = Sponsor.new(event: @event, tier: "gold")
    assert_not sponsor.valid?
    assert_includes sponsor.errors[:organization], "must exist"
  end
end
