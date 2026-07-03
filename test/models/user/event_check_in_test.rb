require "test_helper"

class User::EventCheckInTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:future_conference)
    @other_event = events(:wnb_rb_meetup)

    # Create a passport ConnectedAccount for the user
    @passport = ConnectedAccount.create!(user: @user, provider: "passport", uid: "ABC123")
  end

  test "checked_in_events returns events with checked-in attendance" do
    EventCheckIn.create!(connect_id: "ABC123", event: @event, checked_in_at: Time.current)

    assert_includes @user.checked_in_events, @event
  end

  test "checked_in_events returns empty when user has no passports" do
    user_no_passport = users(:two)

    assert_empty user_no_passport.checked_in_events
  end

  test "checked_in_events returns empty when user has passport but no checked-in attendance" do
    assert_empty @user.checked_in_events
  end

  test "checked_in_events includes events from multiple passports" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "DEF456")
    EventCheckIn.create!(connect_id: "ABC123", event: @event, checked_in_at: Time.current)
    EventCheckIn.create!(connect_id: "DEF456", event: @other_event, checked_in_at: Time.current)

    result = @user.checked_in_events
    assert_includes result, @event
    assert_includes result, @other_event
  end

  test "all_attended_events includes both self-reported and checked-in events" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    EventCheckIn.create!(connect_id: "ABC123", event: @other_event, checked_in_at: Time.current)

    result = @user.all_attended_events
    assert_includes result, @event
    assert_includes result, @other_event
  end

  test "all_attended_events deduplicates events present in both sources" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    EventCheckIn.create!(connect_id: "ABC123", event: @event, checked_in_at: Time.current)

    result = @user.all_attended_events
    assert_equal 1, result.where(id: @event.id).count
  end

  test "all_attended_events works with only self-reported attendance" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")

    result = @user.all_attended_events
    assert_includes result, @event
  end

  test "checked_in_event_ids returns a Set of event IDs" do
    EventCheckIn.create!(connect_id: "ABC123", event: @event, checked_in_at: Time.current)
    EventCheckIn.create!(connect_id: "ABC123", event: @other_event, checked_in_at: Time.current)

    ids = @user.checked_in_event_ids
    assert_kind_of Set, ids
    assert_includes ids, @event.id
    assert_includes ids, @other_event.id
  end
end
