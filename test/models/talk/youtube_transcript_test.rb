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

  test "fetch requests the talk's language with an English fallback" do
    talk = Talk.new(video_provider: "youtube", video_id: "abc12345678", language: "ja")
    captured = nil

    YouTube::Transcript.stub(:get, ->(_video_id, languages:) { captured = languages }) do
      talk.youtube_transcript.fetch
    end

    assert_equal ["ja", "en"], captured
  end

  test "fetch_and_store! stores the fetched transcript" do
    talk = Talk.create!(title: "T", video_provider: "youtube", video_id: "yt-store", date: Date.today, static_id: "yt-transcript-store")

    YouTube::Transcript.stub(:tracks, [track([["hello world", 0, 5]], is_generated: true)]) do
      talk.youtube_transcript.fetch_and_store!
    end

    assert talk.reload.talk_transcript.raw_transcript.present?
    assert talk.transcript.cues.first.is_a?(Talk::Transcript::Cue)
    assert_equal true, talk.talk_transcript.auto_generated
  end

  test "fetch_and_store! is a no-op for non-youtube videos" do
    talk = Talk.create!(title: "T", video_provider: "not_recorded", video_id: "x", date: Date.today, static_id: "yt-transcript-noop")

    talk.youtube_transcript.fetch_and_store!

    assert_nil talk.reload.talk_transcript
  end

  test "fetch_and_store! slices the transcript onto parent-provider segments, leaving own-video children alone" do
    parent = Talk.create!(title: "Lightning Talks", video_provider: "youtube", video_id: "lt-parent", date: Date.today, static_id: "lt-parent")
    segment = Talk.create!(title: "A", video_provider: "parent", video_id: "lt-a", parent_talk: parent, start_seconds: 0, end_seconds: 100, date: Date.today, static_id: "lt-a")
    own_video_child = Talk.create!(title: "B", video_provider: "youtube", video_id: "lt-own", parent_talk: parent, date: Date.today, static_id: "lt-own")

    YouTube::Transcript.stub(:tracks, [track([["first talk", 30, 5]])]) do
      parent.youtube_transcript.fetch_and_store!
    end

    assert_nil parent.reload.talk_transcript, "parent should not keep the whole transcript"
    assert_equal ["first talk"], segment.reload.transcript.cues.map(&:text)
    assert_nil own_video_child.reload.talk_transcript, "own-video child should be untouched"
  end

  test "fetch_and_store! skips a segment with no cues in its range" do
    parent = Talk.create!(title: "Lightning Talks", video_provider: "youtube", video_id: "lt-parent2", date: Date.today, static_id: "lt-parent2")
    segment = Talk.create!(title: "A", video_provider: "parent", video_id: "lt-a2", parent_talk: parent, start_seconds: 500, end_seconds: 600, date: Date.today, static_id: "lt-a2")

    YouTube::Transcript.stub(:tracks, [track([["intro", 30, 5]])]) do
      parent.youtube_transcript.fetch_and_store!
    end

    assert_nil segment.reload.talk_transcript
  end

  test "fetch_and_store! stores one transcript row per returned language" do
    talk = Talk.create!(title: "Keynote", video_provider: "youtube", video_id: "ml-vid", date: Date.today, static_id: "ml-talk", language: "ja")

    tracks = [
      track([["こんにちは", 0, 5]], language_code: "ja", is_generated: true),
      track([["hello", 0, 5]], language_code: "en", is_generated: false)
    ]

    YouTube::Transcript.stub(:tracks, tracks) do
      talk.youtube_transcript.fetch_and_store!
    end

    talk.reload

    assert_equal ["en", "ja"], talk.transcript_languages.sort
    assert_equal "こんにちは", talk.transcript(language: "ja").cues.first.text
    assert_equal "hello", talk.transcript(language: "en").cues.first.text
  end

  test "fetch_and_store! flags auto-translated tracks and labels by the returned language" do
    talk = Talk.create!(title: "JP Talk", video_provider: "youtube", video_id: "jp-vid", date: Date.today, static_id: "jp-talk", language: "ja")

    tracks = [
      track([["こんにちは", 0, 5]], language_code: "ja", is_generated: true, translated: false),
      track([["hello", 0, 5]], language_code: "en", is_generated: true, translated: true)
    ]

    YouTube::Transcript.stub(:tracks, tracks) do
      talk.youtube_transcript.fetch_and_store!
    end

    talk.reload

    assert_equal false, talk.talk_transcript(language: "ja").translated
    assert_equal true, talk.talk_transcript(language: "en").translated
  end

  test "fetch_and_store! records transcript_checked_at even when nothing is found" do
    talk = Talk.create!(title: "No captions", video_provider: "youtube", video_id: "no-cap", date: Date.today, static_id: "no-cap-talk")

    YouTube::Transcript.stub(:tracks, []) do
      talk.youtube_transcript.fetch_and_store!
    end

    assert_nil talk.talk_transcript
    assert_not_nil talk.reload.transcript_checked_at
  end

  private

  def track(snippets, language_code: "en", is_generated: false, translated: false)
    snippet = Struct.new(:text, :start, :duration)

    YouTube::Transcript::Track.new(
      language_code: language_code,
      is_generated: is_generated,
      translated: translated,
      snippets: snippets.map { |text, start, duration| snippet.new(text, start, duration) }
    )
  end
end
