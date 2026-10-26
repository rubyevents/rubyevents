require "test_helper"

class FavoriteUserTest < ActiveSupport::TestCase
  test "mutual_favorite_user association" do
    chael = users(:chael)
    marco = users(:marco)

    favorite1 = FavoriteUser.create!(user: chael, favorite_user: marco)
    favorite2 = FavoriteUser.create!(user: marco, favorite_user: chael)
    favorite3 = FavoriteUser.create!(user: chael, favorite_user: users(:yaroslav))

    assert_equal favorite2, favorite1.mutual_favorite_user
    assert_equal favorite1, favorite2.mutual_favorite_user
    assert_nil favorite3.mutual_favorite_user
  end

  test "build mutual_favorite_user" do
    chael = users(:chael)
    marco = users(:marco)

    favorite1 = FavoriteUser.create!(user: chael, favorite_user: marco)
    favorite2 = favorite1.build_mutual_favorite_user(user: marco, favorite_user: chael)

    assert_equal marco, favorite2.user
    assert_equal chael, favorite2.favorite_user
  end

  test "recommendations_for user with limited watched talks" do
    talk = talks(:lightning_talk)
    user = users(:chael)
    WatchedTalk.create!(user: user, talk: talk, progress_seconds: 100)
    recommendations = FavoriteUser.recommendations_for(user)

    assert recommendations.all? { |fu| fu.user == user }
    assert_equal 5, recommendations.count
    assert recommendations.map(&:favorite_user).all? { |speaker| speaker.talks.any? { |talk| user.watched_talks.exists?(talk_id: talk.id) } }
  end

  test "next_mutual_events_for returns the earliest upcoming shared event per favorite user" do
    chael = users(:chael)
    marco = users(:marco)
    yaroslav = users(:yaroslav)
    future_event = events(:future_conference)
    later_event = Event.create!(name: "Later Conference", series: future_event.series, start_date: 2.months.from_now, end_date: 2.months.from_now, date: 2.months.from_now, kind: :conference)
    past_event = events(:rails_world_2023)

    [future_event, later_event, past_event].each do |event|
      EventParticipation.create!(user: chael, event: event, role: :attendee)
      EventParticipation.create!(user: marco, event: event, role: :attendee)
    end
    EventParticipation.create!(user: yaroslav, event: past_event, role: :attendee)

    next_mutual_events = FavoriteUser.next_mutual_events_for(chael, [marco.id, yaroslav.id])

    assert_equal({marco.id => future_event}, next_mutual_events)
  end
end
