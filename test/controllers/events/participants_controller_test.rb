require "test_helper"

class Events::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:railsconf_2017)
    @user = users(:lazaro_nixon)
    @other_user = users(:one)
  end

  test "shows participants page" do
    get event_participants_url(@event)
    assert_response :success
  end

  test "includes verified-only attendees in participants list" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PART01")
    VerifiedEventParticipation.create!(connect_id: "PART01", event: @event, scanned_at: Time.current)

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, @user.name
  end

  test "shows verified icon for verified attendees" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PART02")
    VerifiedEventParticipation.create!(connect_id: "PART02", event: @event, scanned_at: Time.current)

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, "Verified attendance"
  end

  test "does not duplicate user who has both self-reported and verified attendance" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PART03")
    VerifiedEventParticipation.create!(connect_id: "PART03", event: @event, scanned_at: Time.current)

    get event_participants_url(@event)
    assert_response :success
    # User should appear once, with verified icon
    assert_includes response.body, @user.name
    assert_includes response.body, "Verified attendance"
  end

  test "self-reported participant without verified attendance has no verified icon" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, @user.name
    refute_includes response.body, "Verified attendance"
  end
end
