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

  test "includes checked-in-only attendees in participants list" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PART01")
    EventCheckIn.create!(connect_id: "PART01", event: @event, checked_in_at: Time.current)

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, @user.name
  end

  test "shows checked-in icon for checked-in attendees" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PART02")
    EventCheckIn.create!(connect_id: "PART02", event: @event, checked_in_at: Time.current)

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, "Checked in"
  end

  test "does not duplicate user who has both self-reported and checked-in attendance" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PART03")
    EventCheckIn.create!(connect_id: "PART03", event: @event, checked_in_at: Time.current)

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, @user.name
    assert_includes response.body, "Checked in"
  end

  test "self-reported participant without checked-in attendance has no checked-in icon" do
    EventParticipation.create!(user: @user, event: @event, attended_as: "visitor")

    get event_participants_url(@event)
    assert_response :success
    assert_includes response.body, @user.name
    refute_includes response.body, "Checked in"
  end
end
