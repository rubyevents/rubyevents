require "test_helper"

class Events::ParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:rails_world_2023)
    @user = users(:one)
    @event.event_participations.create!(user: @user, attended_as: "visitor")
  end

  test "should get index" do
    get event_participants_url(@event)
    assert_response :success
    assert_select "div", /#{@user.name}/
  end

  test "should get index for signed in user" do
    sign_in_as @user
    get event_participants_url(@event)
    assert_response :success
    assert_select "div", /#{@user.name}/
  end
end
