require "test_helper"

class EventCheckInTest < ActiveSupport::TestCase
  setup do
    @event = events(:future_conference)
  end

  test "creates checked-in event participation with valid attributes" do
    checkin = EventCheckIn.create!(
      connect_id: "ABC123",
      event: @event,
      checked_in_at: Time.current
    )

    assert checkin.persisted?
  end

  test "normalizes connect_id to uppercase" do
    checkin = EventCheckIn.create!(
      connect_id: "abc123",
      event: @event,
      checked_in_at: Time.current
    )

    assert_equal "ABC123", checkin.connect_id
  end

  test "strips whitespace from connect_id" do
    checkin = EventCheckIn.create!(
      connect_id: "  abc123  ",
      event: @event,
      checked_in_at: Time.current
    )

    assert_equal "ABC123", checkin.connect_id
  end

  test "rejects duplicate connect_id and event_id" do
    EventCheckIn.create!(
      connect_id: "ABC123",
      event: @event,
      checked_in_at: Time.current
    )

    duplicate = EventCheckIn.new(
      connect_id: "ABC123",
      event: @event,
      checked_in_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:connect_id], "has already been taken"
  end

  test "requires connect_id" do
    checkin = EventCheckIn.new(event: @event, checked_in_at: Time.current)

    assert_not checkin.valid?
    assert_includes checkin.errors[:connect_id], "can't be blank"
  end

  test "requires event" do
    checkin = EventCheckIn.new(connect_id: "ABC123", checked_in_at: Time.current)

    assert_not checkin.valid?
    assert_includes checkin.errors[:event], "must exist"
  end

  test "requires checked_in_at" do
    checkin = EventCheckIn.new(connect_id: "ABC123", event: @event)

    assert_not checkin.valid?
    assert_includes checkin.errors[:checked_in_at], "can't be blank"
  end

  test "creates a visitor participation when the passport resolves to a user" do
    user = users(:one)
    user.connected_accounts.create!(provider: :passport, uid: "PASS123")

    assert_difference -> { user.event_participations.count }, 1 do
      EventCheckIn.create!(connect_id: "PASS123", event: @event, checked_in_at: Time.current)
    end

    participation = user.event_participations.find_by(event: @event)
    assert participation.attended_as_visitor?
  end

  test "does not create a participation for an unclaimed passport" do
    assert_no_difference -> { EventParticipation.count } do
      EventCheckIn.create!(connect_id: "UNCLAIMED", event: @event, checked_in_at: Time.current)
    end
  end

  test "does not create a duplicate participation when one already exists" do
    user = users(:one)
    user.connected_accounts.create!(provider: :passport, uid: "PASS123")
    user.event_participations.create!(event: @event, attended_as: :speaker)

    assert_no_difference -> { user.event_participations.count } do
      EventCheckIn.create!(connect_id: "PASS123", event: @event, checked_in_at: Time.current)
    end
  end
end
