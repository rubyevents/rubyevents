require "application_system_test_case"

class TalksTest < ApplicationSystemTestCase
  setup do
    @talk = talks(:one)
    @event = events(:rails_world_2023)
    @talk.update(event: @event)
  end

  test "visiting the index" do
    visit talks_url
    assert_selector "h1", text: "Video Recordings of Talks"
  end

  test "should update Talk" do
    visit talk_url(@talk)
    click_on "Edit", match: :first

    fill_in "Description", with: @talk.description
    fill_in "Title", with: @talk.title
    click_on "Suggest modifications"

    assert_text "Your suggestion was successfully created and will be reviewed soon."
  end

  test "should provide a link to the event of the talk" do
    visit talk_url(@talk)

    find("#explore-event").click

    assert_current_path event_path(@event)
    assert_text @event.name
  end

  # test "renders some related talks" do
  #   visit talk_url(@talk)

  #   assert_selector "#recommended_talks"
  #   assert_selector "[data-talk-horizontal-card]", count: [Talk.excluding(@talk).count, 6].min
  # end
end
