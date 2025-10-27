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
    assert_equal 3, user.event_participations.count
    assert_equal "keynote_speaker", user.main_participation_to(event).attended_as
  end
end
