class Recurring::TranscriptBackfillJob < ApplicationJob
  queue_as :low

  BATCH_SIZE = Integer(ENV.fetch("TRANSCRIPT_BACKFILL_BATCH_SIZE", 10))

  def perform
    return if ENV["SEED_SMOKE_TEST"]

    Talk.pending_transcript.limit(BATCH_SIZE).each do |talk|
      talk.youtube_transcript.fetch_and_store_later!
    end
  end
end
