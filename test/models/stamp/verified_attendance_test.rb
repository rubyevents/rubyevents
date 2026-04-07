require "test_helper"

class Stamp::VerifiedAttendanceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:no_sponsors_event) # conference in GB
    @passport = ConnectedAccount.create!(user: @user, provider: "passport", uid: "STAMP01")
  end

  test "verified attendance earns country stamp" do
    VerifiedEventParticipation.create!(connect_id: "STAMP01", event: @event, scanned_at: Time.current)

    stamps = Stamp.for_user(@user)
    country_codes = stamps.select(&:has_country?).map(&:code)
    assert_includes country_codes, @event.country_code
  end

  test "verified attendance earns attend one event stamp" do
    VerifiedEventParticipation.create!(connect_id: "STAMP01", event: @event, scanned_at: Time.current)

    stamps = Stamp.for_user(@user)
    stamp_codes = stamps.map(&:code)
    assert_includes stamp_codes, "ATTEND-ONE-EVENT"
  end

  test "same event in both self-reported and verified does not duplicate stamps" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    VerifiedEventParticipation.create!(connect_id: "STAMP01", event: @event, scanned_at: Time.current)

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
