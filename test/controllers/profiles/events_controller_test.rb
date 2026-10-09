require "test_helper"

class Profiles::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @event = events(:future_conference)
    @other_event = events(:no_sponsors_event)
    sign_in_as @user
  end

  test "shows self-reported events" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, @event.name
  end

  test "shows checked-in-only events merged into the list" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "EVT001")
    EventCheckIn.create!(connect_id: "EVT001", event: @event, checked_in_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, @event.name
  end

  test "shows checked-in badge on checked-in events" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "EVT002")
    EventCheckIn.create!(connect_id: "EVT002", event: @event, checked_in_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, "Checked in"
  end

  test "event with both self-reported and checked-in shows checked-in indicator" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "EVT003")
    EventCheckIn.create!(connect_id: "EVT003", event: @event, checked_in_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, @event.name
    assert_includes response.body, "Checked in"
  end

  test "does not show checked-in events for unclaimed passport" do
    EventCheckIn.create!(connect_id: "ORPHAN", event: @event, checked_in_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    refute_includes response.body, "Checked in"
  end

  test "shows empty state when user has no attendance" do
    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, "No participated events yet"
  end
end
