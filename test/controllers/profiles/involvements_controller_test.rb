require "test_helper"

class Profiles::InvolvementsControllerTest < ActionDispatch::IntegrationTest
  test "user with event involvements" do
    user = users(:one)
    event = events(:railsconf_2017)
    EventInvolvement.create!(involvementable: user, event: event, role: "volunteer")

    get profile_involvements_path(user)

    assert_response :success
  end

  test "user without involvements" do
    user = users(:one)

    get profile_involvements_path(user)

    assert_response :success
  end

  test "user with event and meetup involvements" do
    user = users(:one)
    event = events(:tropical_rb_2024)
    meetup = events(:wnb_rb_meetup)
    EventInvolvement.create!(involvementable: user, event: event, role: "organizer")
    EventInvolvement.create!(involvementable: user, event: meetup, role: "organizer")

    get profile_involvements_path(user)

    assert_response :success
  end
end
