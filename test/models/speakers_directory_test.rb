require "test_helper"

class SpeakersDirectoryTest < ActiveSupport::TestCase
  setup do
    @event = events(:railsconf_2017)
  end

  test "upcoming debuts include speakers whose first talk is still ahead" do
    debutant = User.create!(name: "First Timer")
    create_talk(debutant, date: 2.weeks.from_now.to_date)

    highlight = SpeakersDirectory.new.upcoming_debuts.find { |highlight| highlight.speaker == debutant }

    assert highlight
    assert_equal @event, highlight.event
    assert_equal 2.weeks.from_now.to_date, highlight.date
  end

  test "upcoming debuts leave out speakers who have spoken before" do
    veteran = User.create!(name: "Returning Speaker")
    create_talk(veteran, date: 1.year.ago.to_date)
    create_talk(veteran, date: 2.weeks.from_now.to_date)

    assert_not_includes SpeakersDirectory.new.upcoming_debuts.map(&:speaker), veteran
  end

  test "speakers giving their first talk today are upcoming debuts, not new voices" do
    debutant = User.create!(name: "Debuting Today")
    create_talk(debutant, date: Date.current)

    directory = SpeakersDirectory.new

    assert_includes directory.upcoming_debuts.map(&:speaker), debutant
    assert_not_includes directory.new_voices.map(&:speaker), debutant
  end

  test "new voices include speakers whose first talk was in the last year" do
    newcomer = User.create!(name: "Recent Newcomer")
    create_talk(newcomer, date: 1.month.ago.to_date)

    assert_includes SpeakersDirectory.new.new_voices.map(&:speaker), newcomer
  end

  private

  def create_talk(user, date:)
    talk = Talk.create!(title: "Talk by #{user.name} on #{date}", date: date, event: @event, static_id: "test-#{user.id}-#{date}")
    UserTalk.create!(user: user, talk: talk)
  end
end
