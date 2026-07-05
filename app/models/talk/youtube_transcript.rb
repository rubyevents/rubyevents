class Talk::YouTubeTranscript < ActiveRecord::AssociatedObject
  performs :fetch_and_store!, retries: 3 do
    limits_concurrency to: 1, key: "youtube_transcript"
  end

  def available?
    talk.youtube? && talk.video_id.present?
  end

  def fetch(languages: preferred_languages)
    return unless available?

    YouTube::Transcript.get(talk.video_id, languages: languages)
  end

  def fetch_and_store!
    return unless available?

    YouTube::Transcript.tracks(talk.video_id, languages: preferred_languages).each do |track|
      store_track(track)
    end

    talk.update_column(:transcript_checked_at, Time.current)
  end

  private

  def preferred_languages
    [talk.language, "en"].compact.uniq
  end

  def store_track(track)
    raw = Talk::Transcript::CueList.from_youtube(track)
    segments = talk.child_talks.where(video_provider: "parent")

    if segments.any?
      segments.each { |child| store_slice(child, track, raw) }
    else
      store(talk, track, raw)
    end
  end

  def store_slice(child, track, raw)
    return unless child.start_seconds && child.end_seconds

    slice = raw.slice(child.start_seconds, child.end_seconds).presence
    return unless slice

    store(child, track, slice)
  end

  def store(talk, track, raw)
    transcript = talk.talk_transcripts.find_or_initialize_by(language: track.language_code)

    transcript.update!(
      raw_transcript: raw,
      auto_generated: track.is_generated,
      translated: track.translated
    )
  end
end
