require "test_helper"

class EventParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:future_conference)
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

  test "interested users are excluded from going participants" do
    @user.event_participations.create!(event: @event, role: "interested")

    assert_equal 0, @event.going_participants.count
    assert_equal 1, @event.interested_participants.count
    assert_includes @event.interested_participants, @user
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

  test "past events cannot be marked as interested" do
    sign_in_as @user
    past_event = events(:railsconf_2025)

    assert_no_difference -> { @user.event_participations.count } do
      post event_event_participations_url(past_event), params: {role: "interested"}
    end
  end

  test "past events can be marked as attended" do
    sign_in_as @user
    past_event = events(:railsconf_2025)

    post event_event_participations_url(past_event), params: {role: "attendee"}

    assert_equal ["attendee"], @user.event_participations.where(event: past_event).pluck(:role)
  end

  test "past events only offer I was there" do
    sign_in_as @user

    get event_url(events(:railsconf_2025))

    assert_response :success
    assert_select ".participation_button", text: /I was there/
    assert_select ".participation_button", text: /Interested/, count: 0
    assert_select ".participation_button", text: /Going/, count: 0
  end

  test "upcoming events offer going and interested" do
    sign_in_as @user

    get event_url(@event)

    assert_response :success
    assert_select ".participation_button", text: /Going/
    assert_select ".participation_button", text: /Interested/
  end
end
