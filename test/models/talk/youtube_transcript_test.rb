# frozen_string_literal: true

require "test_helper"

class Talk::YouTubeTranscriptTest < ActiveSupport::TestCase
  test "available? is true only for youtube-backed videos with a video_id" do
    assert Talk.new(video_provider: "youtube", video_id: "9LfmrkyP81M").youtube_transcript.available?
    assert_not Talk.new(video_provider: "youtube", video_id: "").youtube_transcript.available?
    assert_not Talk.new(video_provider: "not_recorded", video_id: "x").youtube_transcript.available?
  end

  test "fetch returns nil for non-youtube videos without hitting the API" do
    assert_nil Talk.new(video_provider: "vimeo", video_id: "123").youtube_transcript.fetch
  end

  test "fetch_and_store! stores the fetched transcript" do
    talk = Talk.create!(title: "T", video_provider: "youtube", video_id: "9LfmrkyP81M", date: Date.today, static_id: "yt-transcript-store")

    VCR.use_cassette("youtube_video_transcript", match_requests_on: [:method]) do
      talk.youtube_transcript.fetch_and_store!
    end

    assert talk.reload.talk_transcript.raw_transcript.present?
    assert talk.transcript.cues.first.is_a?(Cue)
  end

  test "fetch_and_store! is a no-op for non-youtube videos" do
    talk = Talk.create!(title: "T", video_provider: "not_recorded", video_id: "x", date: Date.today, static_id: "yt-transcript-noop")

    talk.youtube_transcript.fetch_and_store!

    assert_nil talk.reload.talk_transcript
  end
end
