require "test_helper"

class Events::ParticipationHeaderTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:future_conference)
    @user = users(:one)
    @user.event_participations.create!(event: @event, role: "interested")
    sign_in_as @user
  end

  test "header shows interested state on the event overview" do
    get event_path(@event)

    assert_response :success
    assert_select ".participation_button", text: /#{I18n.t("event_participation.actions.mark_as_going")}/
  end

  test "header shows interested state on the CFP page" do
    get event_cfp_index_path(@event)

    assert_response :success
    assert_select ".participation_button", text: /#{I18n.t("event_participation.actions.mark_as_going")}/
  end

  test "header shows interested state on the talks page" do
    get event_talks_path(@event)

    assert_response :success
    assert_select ".participation_button", text: /#{I18n.t("event_participation.actions.mark_as_going")}/
  end

  test "header shows interested state on the sponsors page" do
    get event_sponsors_path(@event)

    assert_response :success
    assert_select ".participation_button", text: /#{I18n.t("event_participation.actions.mark_as_going")}/
  end
end
