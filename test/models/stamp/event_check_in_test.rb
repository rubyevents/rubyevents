require "test_helper"

class Stamp::EventCheckInTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:no_sponsors_event) # conference in GB
    @passport = ConnectedAccount.create!(user: @user, provider: "passport", uid: "STAMP01")
  end

  test "checked-in attendance earns country stamp" do
    EventCheckIn.create!(connect_id: "STAMP01", event: @event, checked_in_at: Time.current)

    stamps = Stamp.for_user(@user)
    country_codes = stamps.select(&:has_country?).map(&:code)
    assert_includes country_codes, @event.country_code
  end

  test "checked-in attendance earns attend one event stamp" do
    EventCheckIn.create!(connect_id: "STAMP01", event: @event, checked_in_at: Time.current)

    stamps = Stamp.for_user(@user)
    stamp_codes = stamps.map(&:code)
    assert_includes stamp_codes, "ATTEND-ONE-EVENT"
  end

  test "same event in both self-reported and checked-in does not duplicate stamps" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    EventCheckIn.create!(connect_id: "STAMP01", event: @event, checked_in_at: Time.current)

    stamps = Stamp.for_user(@user)
    country_stamps = stamps.select { |s| s.code == @event.country_code }
    assert_equal 1, country_stamps.size
  end

  test "user without passport gets stamps from self-reported only" do
    user_no_passport = users(:two)
    EventParticipation.create!(user: user_no_passport, event: @event, attended_as: "visitor")

    stamps = Stamp.for_user(user_no_passport)
    country_codes = stamps.select(&:has_country?).map(&:code)
    assert_includes country_codes, @event.country_code
  end
end
