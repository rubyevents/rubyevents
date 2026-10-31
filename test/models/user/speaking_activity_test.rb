require "test_helper"

class User::SpeakingActivityTest < ActiveSupport::TestCase
  setup do
    @event = events(:railsconf_2017)
  end

  test "spans the years of a speaker's talks and names the latest past event" do
    speaker = User.create!(name: "Long Time Speaker")
    create_talk(speaker, date: Date.new(2015, 4, 1))
    create_talk(speaker, date: Date.new(2019, 4, 1))

    activity = User::SpeakingActivity.for([speaker])[speaker.id]

    assert_equal 2015, activity.first_year
    assert_equal 2019, activity.last_year
    assert_equal @event, activity.latest_event
  end

  private

  def create_talk(user, date:)
    talk = Talk.create!(title: "Talk by #{user.name} on #{date}", date: date, event: @event, static_id: "test-#{user.id}-#{date}")
    UserTalk.create!(user: user, talk: talk)
  end
end
