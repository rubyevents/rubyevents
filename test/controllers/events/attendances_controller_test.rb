require "test_helper"

class Events::AttendancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @event = events(:rails_world_2023)
    @parent_talk = talks(:one)
    @parent_talk.update!(event: @event)

    @child_talk = Talk.create!(
      title: "Lightning segment",
      description: "Nested lightning talk",
      slug: "lightning-segment-#{SecureRandom.hex(4)}",
      kind: "lightning_talk",
      video_provider: "parent",
      event: @event,
      date: @event.date,
      static_id: "lightning-segment-#{SecureRandom.hex(4)}",
      parent_talk: @parent_talk
    )

    @user.watched_talks.where(talk: [@parent_talk, @child_talk]).destroy_all
    @event.event_participations.create!(user: @user, attended_as: "visitor")
    sign_in_as @user
  end

  test "top_level talks exclude nested child talks" do
    assert_includes @event.top_level_talks, @parent_talk
    assert_not_includes @event.top_level_talks, @child_talk
    assert_equal @event.talks.count - 1, @event.top_level_talks.count
  end

  test "index stats count only top-level watched talks" do
    @user.watched_talks.create!(talk: @parent_talk, watched: true, watched_on: "in_person", watched_at: @parent_talk.date)
    @user.watched_talks.create!(talk: @child_talk, watched: true, watched_on: "in_person", watched_at: @child_talk.date)

    watched = @user.watched_talks.joins(:talk).merge(Talk.top_level).where(talks: {event_id: @event.id})
    assert_equal 1, watched.count
    assert_equal [@parent_talk.id], watched.pluck(:talk_id)
  end

  test "toggle attendance turbo counter ignores nested child talks" do
    @user.watched_talks.create!(talk: @child_talk, watched: true, watched_on: "in_person", watched_at: @child_talk.date)

    post toggle_attendance_talk_watched_talk_path(@parent_talk), as: :turbo_stream

    assert_response :success

    total_talks = @event.talks_in_running_order(child_talks: false).count
    assert_includes @response.body, ">1/#{total_talks}<"
    assert_not_includes @response.body, ">#{@event.talks.count}<"
  end
end
