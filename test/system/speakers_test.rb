require "application_system_test_case"

class SpeakersTest < ApplicationSystemTestCase
  setup do
    @speaker = users(:marco)
  end

  test "broadcast a speaker about partial" do
    # ensure Turbo Stream broadcast is working with Litestack
    visit speaker_url(@speaker)
    wait_for_turbo_stream_connected(streamable: @speaker)

    @speaker.update(bio: "New bio")
    @speaker.broadcast_header

    assert_text "New bio"
  end
end
