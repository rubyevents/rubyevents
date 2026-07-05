# frozen_string_literal: true

require "test_helper"

class Recurring::TranscriptBackfillJobTest < ActiveJob::TestCase
  test "enqueues a transcript fetch for youtube talks missing one" do
    Talk.create!(title: "Backfill me", video_provider: "youtube", video_id: "backfill-vid", date: Date.today, static_id: "backfill-talk")

    before = enqueued_jobs.size
    Recurring::TranscriptBackfillJob.perform_now

    assert_operator enqueued_jobs.size, :>, before
  end

  test "skips youtube talks checked within the recheck window" do
    never = Talk.create!(title: "Never checked", video_provider: "youtube", video_id: "pt-never", date: Date.today, static_id: "pt-never")
    recent = Talk.create!(title: "Checked today", video_provider: "youtube", video_id: "pt-recent", date: Date.today, static_id: "pt-recent", transcript_checked_at: Time.current)

    ids = Talk.pending_transcript.ids

    assert_includes ids, never.id
    assert_not_includes ids, recent.id
  end

  test "enqueues nothing when every youtube talk already has a transcript" do
    Talk.youtube.left_joins(:talk_transcripts).where(talk_transcripts: {id: nil}).find_each do |talk|
      talk.talk_transcripts.create!(language: "en", raw_transcript: Talk::Transcript::CueList.new(cues: []))
    end

    assert_no_enqueued_jobs do
      Recurring::TranscriptBackfillJob.perform_now
    end
  end
end
