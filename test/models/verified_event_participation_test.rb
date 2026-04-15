require "test_helper"

class VerifiedEventParticipationTest < ActiveSupport::TestCase
  setup do
    @event = events(:future_conference)
  end

  test "creates verified event participation with valid attributes" do
    vep = VerifiedEventParticipation.create!(
      connect_id: "ABC123",
      event: @event,
      scanned_at: Time.current
    )
    assert vep.persisted?
  end

  test "normalizes connect_id to uppercase" do
    vep = VerifiedEventParticipation.create!(
      connect_id: "abc123",
      event: @event,
      scanned_at: Time.current
    )
    assert_equal "ABC123", vep.connect_id
  end

  test "strips whitespace from connect_id" do
    vep = VerifiedEventParticipation.create!(
      connect_id: "  abc123  ",
      event: @event,
      scanned_at: Time.current
    )
    assert_equal "ABC123", vep.connect_id
  end

  test "rejects duplicate connect_id and event_id" do
    VerifiedEventParticipation.create!(
      connect_id: "ABC123",
      event: @event,
      scanned_at: Time.current
    )

    duplicate = VerifiedEventParticipation.new(
      connect_id: "ABC123",
      event: @event,
      scanned_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:connect_id], "has already been taken"
  end

  test "requires connect_id" do
    vep = VerifiedEventParticipation.new(event: @event, scanned_at: Time.current)
    assert_not vep.valid?
    assert_includes vep.errors[:connect_id], "can't be blank"
  end

  test "requires event" do
    vep = VerifiedEventParticipation.new(connect_id: "ABC123", scanned_at: Time.current)
    assert_not vep.valid?
    assert_includes vep.errors[:event], "must exist"
  end

  test "requires scanned_at" do
    vep = VerifiedEventParticipation.new(connect_id: "ABC123", event: @event)
    assert_not vep.valid?
    assert_includes vep.errors[:scanned_at], "can't be blank"
  end
end
