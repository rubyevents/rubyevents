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
end
