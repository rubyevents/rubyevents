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

  test "shows verified-only events merged into the list" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "EVT001")
    VerifiedEventParticipation.create!(connect_id: "EVT001", event: @event, scanned_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, @event.name
  end

  test "shows verified badge on verified events" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "EVT002")
    VerifiedEventParticipation.create!(connect_id: "EVT002", event: @event, scanned_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, "Verified"
  end

  test "event with both self-reported and verified shows verified indicator" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "EVT003")
    VerifiedEventParticipation.create!(connect_id: "EVT003", event: @event, scanned_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, @event.name
    assert_includes response.body, "Verified"
  end

  test "does not show verified events for unclaimed passport" do
    # Verified attendance exists but no ConnectedAccount links it to the user
    VerifiedEventParticipation.create!(connect_id: "ORPHAN", event: @event, scanned_at: Time.current)

    get profile_events_url(@user)
    assert_response :success
    refute_includes response.body, "Verified"
  end

  test "shows empty state when user has no attendance" do
    get profile_events_url(@user)
    assert_response :success
    assert_includes response.body, "No participated events yet"
  end
end
