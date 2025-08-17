require "application_system_test_case"

class SpeakersTest < ApplicationSystemTestCase
  setup do
    @speaker = users(:marco)
  end

  # TODO: Re-enable when the user/speaker profile is ready
  # test "should update Speaker" do
  #   visit speaker_url(@speaker)
  #   assert_selector "h1", text: @speaker.name
  #   click_on "Suggest improvements"

  #   assert_text "Suggesting a modification"

  #   fill_in "Bio", with: @speaker.bio
  #   fill_in "Name", with: @speaker.name
  #   fill_in "Twitter", with: @speaker.twitter
  #   fill_in "Website", with: @speaker.website
  #   click_on "Suggest modifications"

  #   assert_text "Your suggestion was successfully created and will be reviewed soon."
  # end

  test "broadcast a speaker about partial" do
    # ensure Turbo Stream broadcast is working with Litestack
    visit speaker_url(@speaker)
    wait_for_turbo_stream_connected(streamable: @speaker)

    @speaker.update(bio: "New bio")
    @speaker.broadcast_header

    assert_text "New bio"
  end
end
