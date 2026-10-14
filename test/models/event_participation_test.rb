require "test_helper"

class EventParticipationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @event = events(:rails_world_2023)
  end

  test "allows only one participation per user and event" do
    EventParticipation.create!(user: @user, event: @event, role: :attendee)

    duplicate = EventParticipation.new(user: @user, event: @event, role: :speaker)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "rejects unknown roles" do
    participation = EventParticipation.new(user: @user, event: @event, role: :keynote_speaker)

    assert_not participation.valid?
    assert_includes participation.errors[:role], "is not included in the list"
  end

  test "record creates a participation" do
    participation = EventParticipation.record(user: @user, event: @event, role: :interested)

    assert participation.persisted?
    assert participation.interested?
  end

  test "record upgrades interested to attendee" do
    EventParticipation.create!(user: @user, event: @event, role: :interested)

    EventParticipation.record(user: @user, event: @event, role: :attendee)

    assert_equal ["attendee"], @user.event_participations.where(event: @event).pluck(:role)
  end

  test "record upgrades attendee to speaker" do
    EventParticipation.create!(user: @user, event: @event, role: :attendee)

    EventParticipation.record(user: @user, event: @event, role: :speaker)

    assert_equal ["speaker"], @user.event_participations.where(event: @event).pluck(:role)
  end

  test "record never downgrades" do
    EventParticipation.create!(user: @user, event: @event, role: :speaker)

    EventParticipation.record(user: @user, event: @event, role: :attendee)
    EventParticipation.record(user: @user, event: @event, role: :interested)

    assert_equal ["speaker"], @user.event_participations.where(event: @event).pluck(:role)
  end

  test "going? is true for speakers and attendees only" do
    assert EventParticipation.new(role: :speaker).going?
    assert EventParticipation.new(role: :attendee).going?
    assert_not EventParticipation.new(role: :interested).going?
  end

  test "going scope excludes interested" do
    EventParticipation.create!(user: @user, event: @event, role: :attendee)
    EventParticipation.create!(user: @user, event: events(:railsconf_2025), role: :interested)

    assert_equal ["attendee"], @user.event_participations.going.pluck(:role)
  end

  test "going participants include speakers and attendees but not interested users" do
    speaker = users(:two)
    interested = User.create!(name: "Interested User", github_handle: "interested-user")
    EventParticipation.create!(user: @user, event: @event, role: :attendee)
    EventParticipation.create!(user: speaker, event: @event, role: :speaker)
    EventParticipation.create!(user: interested, event: @event, role: :interested)

    assert_equal [@user, speaker].sort_by(&:id), @event.going_participants.sort_by(&:id)
    assert_equal [interested], @event.interested_participants.to_a
    assert_equal 3, @event.participants.count
  end

  test "going_events and attended_events exclude interested events" do
    EventParticipation.create!(user: @user, event: @event, role: :interested)

    assert_includes @user.interested_events, @event
    assert_includes @user.participated_events, @event
    assert_not_includes @user.going_events, @event
    assert_not_includes @user.attended_events, @event
  end

  test "attended_events only includes past events" do
    upcoming = events(:future_conference)
    EventParticipation.create!(user: @user, event: @event, role: :attendee)
    EventParticipation.create!(user: @user, event: upcoming, role: :attendee)

    assert_equal [@event, upcoming].sort_by(&:id), @user.going_events.sort_by(&:id)
    assert_equal [@event], @user.attended_events.to_a
  end

  test "attended_events includes undated events" do
    meetup = events(:wnb_rb_meetup)
    EventParticipation.create!(user: @user, event: meetup, role: :speaker)

    assert_includes @user.attended_events, meetup
  end

  test "speaking_events only includes speaker participations" do
    EventParticipation.create!(user: @user, event: @event, role: :speaker)
    EventParticipation.create!(user: @user, event: events(:railsconf_2025), role: :attendee)

    assert_equal [@event], @user.speaking_events.to_a
  end
end
