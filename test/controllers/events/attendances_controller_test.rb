require "test_helper"

class Events::AttendancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:zero_talks)
    @talk = talks(:one)
    @event = @talk.event
    Event.reset_counters(@event.id, :talks)
    EventParticipation.create!(user: @user, event: @event, role: :attendee)
    @child_talk = talks(:two, parent: @talk)
    @user.watched_talks.where(talk: [@parent_talk, @child_talk]).destroy_all
    @event.event_participations.create!(user: @user, role: :attendee)
    sign_in_as @user
  end

  test "should show the full talk title in a keyboard-accessible tooltip" do
    get attendance_url(event_slug: @event.slug)

    assert_response :success
    assert_select "##{dom_id(@talk, :attendance)}" do
      assert_select "[data-controller='tooltip'][data-tooltip-content-value=?][tabindex='0']", @talk.title, text: @talk.title
    end
  end

  test "attendance_talks treats lightning blocks as one parent talk" do
    attendance_ids = @event.attendance_talks.pluck(:id)

    assert_includes attendance_ids, @talk.id
    assert_not_includes attendance_ids, @child_talk.id
    assert_equal attendance_ids.size, @event.attendance_talks_count
    assert_operator @event.talks.count, :>, @event.attendance_talks_count
  end

  test "attendance stats ignore watched nested child talks" do
    @user.watched_talks.create!(talk: @talk, watched: true, watched_on: "in_person", watched_at: @talk.date)
    @user.watched_talks.create!(talk: @child_talk, watched: true, watched_on: "in_person", watched_at: @child_talk.date)

    attendance_talk_ids = @event.attendance_talks.pluck(:id)
    watched = @user.watched_talks.where(talk_id: attendance_talk_ids)

    assert_equal 1, watched.count
    assert_equal [@talk.id], watched.pluck(:talk_id)
  end

  test "toggle attendance turbo counter uses the same parent-only total" do
    @user.watched_talks.create!(talk: @child_talk, watched: true, watched_on: "in_person", watched_at: @child_talk.date)

    post toggle_attendance_talk_watched_talk_path(@talk), as: :turbo_stream

    assert_response :success

    total_talks = @event.attendance_talks_count
    assert_includes @response.body, ">1/#{total_talks}<"
    assert_not_includes @response.body, "/#{@event.talks.count}<"
  end

  test "watchable_online is true when a nested lightning segment is recorded" do
    @talk.update!(video_provider: "not_recorded")
    @child_talk.update!(video_provider: "youtube", video_id: "abc123")

    assert_not @talk.video_provider.in?(Talk::WATCHABLE_PROVIDERS)
    assert @talk.watchable_online?
    assert @talk.published?
  end

  test "attendance_talks treats lightning blocks as one parent talk" do
    attendance_ids = @event.attendance_talks.pluck(:id)

    assert_includes attendance_ids, @parent_talk.id
    assert_not_includes attendance_ids, @child_talk.id
    assert_equal attendance_ids.size, @event.attendance_talks_count
    assert_operator @event.talks.count, :>, @event.attendance_talks_count
  end

  test "attendance stats ignore watched nested child talks" do
    @user.watched_talks.create!(talk: @parent_talk, watched: true, watched_on: "in_person", watched_at: @parent_talk.date)
    @user.watched_talks.create!(talk: @child_talk, watched: true, watched_on: "in_person", watched_at: @child_talk.date)

    attendance_talk_ids = @event.attendance_talks.pluck(:id)
    watched = @user.watched_talks.where(talk_id: attendance_talk_ids)

    assert_equal 1, watched.count
    assert_equal [@parent_talk.id], watched.pluck(:talk_id)
  end

  test "toggle attendance turbo counter uses the same parent-only total" do
    @user.watched_talks.create!(talk: @child_talk, watched: true, watched_on: "in_person", watched_at: @child_talk.date)

    post toggle_attendance_talk_watched_talk_path(@parent_talk), as: :turbo_stream

    assert_response :success

    total_talks = @event.attendance_talks_count
    assert_includes @response.body, ">1/#{total_talks}<"
    assert_not_includes @response.body, "/#{@event.talks.count}<"
  end

  test "watchable_online is true when a nested lightning segment is recorded" do
    @parent_talk.update!(video_provider: "not_recorded")
    @child_talk.update!(video_provider: "youtube", video_id: "abc123")

    assert_not @parent_talk.video_provider.in?(Talk::WATCHABLE_PROVIDERS)
    assert @parent_talk.watchable_online?
    assert @parent_talk.published?
  end
end
