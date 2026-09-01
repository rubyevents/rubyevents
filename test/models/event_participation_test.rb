require "test_helper"

class EventParticipationTest < ActiveSupport::TestCase
  test "validates the main participation" do
    user = users(:one)
    user2 = users(:two)
    event = events(:rails_world_2023)
    EventParticipation.create(user: user2, event: event, attended_as: "keynote_speaker")
    EventParticipation.create(user: user, event: event, attended_as: "speaker")
    EventParticipation.create(user: user, event: event, attended_as: "keynote_speaker")
    EventParticipation.create(user: user, event: event, attended_as: "visitor")
    EventParticipation.create(user: user2, event: event, attended_as: "speaker")
    EventParticipation.create(user: user2, event: event, attended_as: "visitor")

    assert_equal 2, user.event_participations.count
    assert_equal "keynote_speaker", user.main_participation_to(event).attended_as
  end

  test "creating a speaker participation removes an existing visitor participation" do
    user = users(:one)
    event = events(:rails_world_2023)
    visitor = EventParticipation.create!(user: user, event: event, attended_as: "visitor")

    EventParticipation.create!(user: user, event: event, attended_as: "speaker")

    assert_not EventParticipation.exists?(visitor.id)
    assert_equal ["speaker"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "creating a keynote_speaker participation removes an existing visitor participation" do
    user = users(:one)
    event = events(:rails_world_2023)
    EventParticipation.create!(user: user, event: event, attended_as: "visitor")

    EventParticipation.create!(user: user, event: event, attended_as: "keynote_speaker")

    assert_equal ["keynote_speaker"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "creating a visitor participation is dropped when a speaker role already exists" do
    user = users(:one)
    event = events(:rails_world_2023)
    EventParticipation.create!(user: user, event: event, attended_as: "speaker")

    visitor = EventParticipation.create(user: user, event: event, attended_as: "visitor")

    assert_not EventParticipation.exists?(visitor.id)
    assert_equal ["speaker"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "a visitor participation is kept when no speaker role exists" do
    user = users(:one)
    event = events(:rails_world_2023)

    visitor = EventParticipation.create!(user: user, event: event, attended_as: "visitor")

    assert EventParticipation.exists?(visitor.id)
    assert_equal "visitor", user.main_participation_to(event).attended_as
  end

  test "dedupe is scoped to the same event" do
    user = users(:one)
    event = events(:rails_world_2023)
    other_event = events(:railsconf_2025)
    other_visitor = EventParticipation.create!(user: user, event: other_event, attended_as: "visitor")

    EventParticipation.create!(user: user, event: event, attended_as: "speaker")

    assert EventParticipation.exists?(other_visitor.id), "visitor participation for a different event must be untouched"
  end

  test "dedupe is scoped to the same user" do
    user = users(:one)
    other_user = users(:two)
    event = events(:rails_world_2023)
    other_visitor = EventParticipation.create!(user: other_user, event: event, attended_as: "visitor")

    EventParticipation.create!(user: user, event: event, attended_as: "speaker")

    assert EventParticipation.exists?(other_visitor.id), "another user's visitor participation must be untouched"
  end

  test "creating interested participation succeeds" do
    user = users(:one)
    event = events(:railsconf_2025)

    interested = EventParticipation.create!(user: user, event: event, attended_as: "interested")

    assert EventParticipation.exists?(interested.id)
    assert_equal "interested", user.main_participation_to(event).attended_as
    assert interested.attended_as_interested?
    assert_not interested.attending?
  end

  test "creating visitor removes existing interested participation" do
    user = users(:one)
    event = events(:railsconf_2025)
    interested = EventParticipation.create!(user: user, event: event, attended_as: "interested")

    EventParticipation.create!(user: user, event: event, attended_as: "visitor")

    assert_not EventParticipation.exists?(interested.id)
    assert_equal ["visitor"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "creating interested removes existing visitor participation" do
    user = users(:one)
    event = events(:railsconf_2025)
    visitor = EventParticipation.create!(user: user, event: event, attended_as: "visitor")

    EventParticipation.create!(user: user, event: event, attended_as: "interested")

    assert_not EventParticipation.exists?(visitor.id)
    assert_equal ["interested"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "creating interested is dropped when a speaker role already exists" do
    user = users(:one)
    event = events(:rails_world_2023)
    EventParticipation.create!(user: user, event: event, attended_as: "speaker")

    interested = EventParticipation.create(user: user, event: event, attended_as: "interested")

    assert_not EventParticipation.exists?(interested.id)
    assert_equal ["speaker"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "creating speaker removes existing interested participation" do
    user = users(:one)
    event = events(:rails_world_2023)
    interested = EventParticipation.create!(user: user, event: event, attended_as: "interested")

    EventParticipation.create!(user: user, event: event, attended_as: "speaker")

    assert_not EventParticipation.exists?(interested.id)
    assert_equal ["speaker"], user.event_participations.where(event: event).pluck(:attended_as)
  end

  test "visitor attending? is true and interested attending? is false" do
    user = users(:one)
    event = events(:railsconf_2025)

    visitor = EventParticipation.create!(user: user, event: event, attended_as: "visitor")
    assert visitor.attending?

    visitor.destroy
    interested = EventParticipation.create!(user: user, event: event, attended_as: "interested")
    assert_not interested.attending?
  end

  test "interested users are excluded from event participants" do
    user = users(:one)
    event = events(:railsconf_2025)
    EventParticipation.create!(user: user, event: event, attended_as: "interested")

    assert_includes event.interested_participants, user
    assert_not_includes event.participants, user
  end

  test "attended_events excludes interested events" do
    user = users(:one)
    event = events(:railsconf_2025)
    EventParticipation.create!(user: user, event: event, attended_as: "interested")

    assert_includes user.interested_events, event
    assert_includes user.participated_events, event
    assert_not_includes user.attended_events, event
  end

  test "attending scope includes visitor and speaker roles only" do
    user = users(:one)
    event = events(:rails_world_2023)
    EventParticipation.create!(user: user, event: event, attended_as: "visitor")

    other_event = events(:railsconf_2025)
    EventParticipation.create!(user: user, event: other_event, attended_as: "interested")

    assert_equal ["visitor"], user.event_participations.attending.pluck(:attended_as)
    assert_equal ["interested"], user.event_participations.interested.pluck(:attended_as)
  end
end
