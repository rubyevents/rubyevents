require "test_helper"

class YouTube::TranscriptTest < ActiveSupport::TestCase
  def setup
    @client = YouTube::Transcript.new
  end

  test "fetch the transcript from a video in vtt format" do
    video_id = "9LfmrkyP81M"

    VCR.use_cassette("youtube_video_transcript", match_requests_on: [:method]) do
      transcript = @client.get(video_id)
      assert_not_nil transcript

      transcript = Transcript.create_from_youtube_transcript(transcript)
      assert_not_empty transcript.cues
      assert transcript.cues.first.is_a?(Cue)
    end
  end

  test "returns nil when the transcript cannot be retrieved" do
    raising_api = Object.new
    def raising_api.fetch(*)
      raise YoutubeRb::Transcript::TranscriptsDisabled.new("9LfmrkyP81M")
    end

    YoutubeRb::Transcript::YouTubeTranscriptApi.stub(:new, raising_api) do
      assert_nil @client.get("9LfmrkyP81M")
    end
  end
end
