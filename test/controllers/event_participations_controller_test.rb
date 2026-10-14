require "test_helper"

class EventParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:railsconf_2025)
    @user = users(:one)
  end

  test "signed in user can mark as going" do
    sign_in_as @user

    assert_difference -> { @user.event_participations.count }, 1 do
      post event_event_participations_url(@event), params: {role: "attendee"}
    end

    participation = @user.event_participations.find_by!(event: @event)
    assert_equal "attendee", participation.role
    assert_redirected_to event_path(@event)
  end

  test "signed in user can mark as interested" do
    sign_in_as @user

    assert_difference -> { @user.event_participations.count }, 1 do
      post event_event_participations_url(@event), params: {role: "interested"}
    end

    participation = @user.event_participations.find_by!(event: @event)
    assert_equal "interested", participation.role
    assert_redirected_to event_path(@event)
  end

  test "marking as going replaces interested" do
    sign_in_as @user
    @user.event_participations.create!(event: @event, role: "interested")

    assert_no_difference -> { @user.event_participations.count } do
      post event_event_participations_url(@event), params: {role: "attendee"}
    end

    assert_equal ["attendee"], @user.event_participations.where(event: @event).pluck(:role)
  end

  test "marking as interested replaces going" do
    sign_in_as @user
    @user.event_participations.create!(event: @event, role: "attendee")

    assert_no_difference -> { @user.event_participations.count } do
      post event_event_participations_url(@event), params: {role: "interested"}
    end

    assert_equal ["interested"], @user.event_participations.where(event: @event).pluck(:role)
  end

  test "signed in user can remove interested participation" do
    sign_in_as @user
    participation = @user.event_participations.create!(event: @event, role: "interested")

    assert_difference -> { @user.event_participations.count }, -1 do
      delete event_event_participation_url(@event, participation)
    end

    assert_redirected_to event_path(@event)
  end

  test "create responds with turbo stream for interested" do
    sign_in_as @user

    post event_event_participations_url(@event),
      params: {role: "interested"},
      as: :turbo_stream

    assert_response :success
    assert_match(/participation_button/, response.body)
    assert_equal "interested", @user.event_participations.find_by!(event: @event).role
  end

  test "interested users are excluded from event attendees" do
    @user.event_participations.create!(event: @event, role: "interested")

    assert_equal 0, @event.attendees.count
    assert_equal 1, @event.interested_users.count
    assert_includes @event.interested_users, @user
  end

  test "speakers cannot change their own role" do
    sign_in_as @user
    @user.event_participations.create!(event: @event, role: "speaker")

    post event_event_participations_url(@event), params: {role: "interested"}

    assert_equal ["speaker"], @user.event_participations.where(event: @event).pluck(:role)
  end

  test "users cannot mark themselves as speakers" do
    sign_in_as @user

    assert_no_difference -> { @user.event_participations.count } do
      post event_event_participations_url(@event), params: {role: "speaker"}
    end
  end
end
