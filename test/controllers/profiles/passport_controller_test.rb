require "test_helper"

class Profiles::PassportControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @event = events(:future_conference)
    @other_event = events(:no_sponsors_event)
    sign_in_as @user
  end

  test "shows the passport timeline with checked-in events" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PASS01")
    EventCheckIn.create!(connect_id: "PASS01", event: @event, checked_in_at: Time.current)

    get profile_passport_index_url(@user)

    assert_response :success
    assert_includes response.body, "Ruby Passport"
    assert_includes response.body, @event.name
    assert_includes response.body, "Checked in"
  end

  test "orders check-ins newest first" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PASS02")
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PASS03")
    EventCheckIn.create!(connect_id: "PASS02", event: @event, checked_in_at: 2.days.ago)
    EventCheckIn.create!(connect_id: "PASS03", event: @other_event, checked_in_at: 1.hour.ago)

    get profile_passport_index_url(@user)

    assert_response :success
    assert_operator response.body.index(@other_event.name), :<, response.body.index(@event.name)
  end

  test "shows an empty state when the passport has no check-ins" do
    ConnectedAccount.create!(user: @user, provider: "passport", uid: "PASS04")

    get profile_passport_index_url(@user)

    assert_response :success
    assert_includes response.body, "No check-ins yet"
  end

  test "does not surface check-ins from passports the user has not claimed" do
    EventCheckIn.create!(connect_id: "ORPHAN", event: @event, checked_in_at: Time.current)

    get profile_passport_index_url(@user)

    assert_response :success
    assert_includes response.body, "No check-ins yet"
    refute_includes response.body, @event.name
  end
end
