require "test_helper"

class EventParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:railsconf_2025)
    @user = users(:one)
  end

  test "signed in user can mark as going" do
    sign_in_as @user

    assert_difference -> { @user.event_participations.count }, 1 do
      post event_event_participations_url(@event), params: {attended_as: "visitor"}
    end

    participation = @user.event_participations.find_by!(event: @event)
    assert_equal "visitor", participation.attended_as
    assert_redirected_to event_path(@event)
  end

  test "signed in user can mark as interested" do
    sign_in_as @user

    assert_difference -> { @user.event_participations.count }, 1 do
      post event_event_participations_url(@event), params: {attended_as: "interested"}
    end

    participation = @user.event_participations.find_by!(event: @event)
    assert_equal "interested", participation.attended_as
    assert_redirected_to event_path(@event)
  end

  test "marking as going replaces interested" do
    sign_in_as @user
    @user.event_participations.create!(event: @event, attended_as: "interested")

    assert_no_difference -> { @user.event_participations.count } do
      post event_event_participations_url(@event), params: {attended_as: "visitor"}
    end

    assert_equal ["visitor"], @user.event_participations.where(event: @event).pluck(:attended_as)
  end

  test "marking as interested replaces going" do
    sign_in_as @user
    @user.event_participations.create!(event: @event, attended_as: "visitor")

    assert_no_difference -> { @user.event_participations.count } do
      post event_event_participations_url(@event), params: {attended_as: "interested"}
    end

    assert_equal ["interested"], @user.event_participations.where(event: @event).pluck(:attended_as)
  end

  test "signed in user can remove interested participation" do
    sign_in_as @user
    participation = @user.event_participations.create!(event: @event, attended_as: "interested")

    assert_difference -> { @user.event_participations.count }, -1 do
      delete event_event_participation_url(@event, participation)
    end

    assert_redirected_to event_path(@event)
  end

  test "create responds with turbo stream for interested" do
    sign_in_as @user

    post event_event_participations_url(@event),
      params: {attended_as: "interested"},
      as: :turbo_stream

    assert_response :success
    assert_match(/participation_button/, response.body)
    assert_equal "interested", @user.event_participations.find_by!(event: @event).attended_as
  end

  test "interested users are excluded from attending participants association" do
    @user.event_participations.create!(event: @event, attended_as: "interested")

    assert_equal 0, @event.participants.count
    assert_equal 1, @event.interested_participants.count
    assert_includes @event.interested_participants, @user
  end
end
