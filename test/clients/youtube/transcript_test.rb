require "test_helper"

class YouTube::TranscriptTest < ActiveSupport::TestCase
  def setup
    @client = YouTube::Transcript.new
  end

  test "fetch the trasncript from a video in vtt format" do
    video_id = "9LfmrkyP81M"

    VCR.use_cassette("youtube_video_transcript", match_requests_on: [:method]) do
      transcript = @client.get(video_id)
      assert_not_nil transcript

      transcript = Transcript.create_from_youtube_transcript(transcript)
      assert_not_empty transcript.cues
      assert transcript.cues.first.is_a?(Cue)
    end
  end
end
