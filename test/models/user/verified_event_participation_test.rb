require "test_helper"

class User::VerifiedEventParticipationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:future_conference)
    @other_event = events(:wnb_rb_meetup)

    # Create a passport ConnectedAccount for the user
    @passport = ConnectedAccount.create!(user: @user, provider: "passport", uid: "ABC123")
  end

  test "verified_attended_events returns events with verified attendance" do
    VerifiedEventParticipation.create!(connect_id: "ABC123", event: @event, scanned_at: Time.current)

    assert_includes @user.verified_attended_events, @event
  end

  test "verified_attended_events returns empty when user has no passports" do
    user_no_passport = users(:two)

    assert_empty user_no_passport.verified_attended_events
  end

  test "verified_attended_events returns empty when user has passport but no verified attendance" do
    assert_empty @user.verified_attended_events
  end

  test "verified_attended_events includes events from multiple passports" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "DEF456")
    VerifiedEventParticipation.create!(connect_id: "ABC123", event: @event, scanned_at: Time.current)
    VerifiedEventParticipation.create!(connect_id: "DEF456", event: @other_event, scanned_at: Time.current)

    result = @user.verified_attended_events
    assert_includes result, @event
    assert_includes result, @other_event
  end

  test "all_attended_events includes both self-reported and verified events" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    VerifiedEventParticipation.create!(connect_id: "ABC123", event: @other_event, scanned_at: Time.current)

    result = @user.all_attended_events
    assert_includes result, @event
    assert_includes result, @other_event
  end

  test "all_attended_events deduplicates events present in both sources" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    VerifiedEventParticipation.create!(connect_id: "ABC123", event: @event, scanned_at: Time.current)

    result = @user.all_attended_events
    assert_equal 1, result.where(id: @event.id).count
  end

  test "all_attended_events works with only self-reported attendance" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")

    result = @user.all_attended_events
    assert_includes result, @event
  end

  test "verified_event_ids returns a Set of event IDs" do
    VerifiedEventParticipation.create!(connect_id: "ABC123", event: @event, scanned_at: Time.current)
    VerifiedEventParticipation.create!(connect_id: "ABC123", event: @other_event, scanned_at: Time.current)

    ids = @user.verified_event_ids
    assert_kind_of Set, ids
    assert_includes ids, @event.id
    assert_includes ids, @other_event.id
  end
end
