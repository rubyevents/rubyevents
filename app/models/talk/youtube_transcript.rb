class Talk::YouTubeTranscript < ActiveRecord::AssociatedObject
  performs :fetch_and_store!, retries: 3

  def available?
    talk.youtube? && talk.video_id.present?
  end

  def fetch(languages: preferred_languages)
    return unless available?

    YouTube::Transcript.get(talk.video_id, languages: languages)
  end

  def fetch_and_store!
    return unless available?

    preferred_languages.each { |language| fetch_and_store_language!(language) }
  end

  private

  def preferred_languages
    [talk.language, "en"].compact.uniq
  end

  def fetch_and_store_language!(language)
    youtube_transcript = YouTube::Transcript.get(talk.video_id, languages: [language])
    return unless youtube_transcript.present?

    raw = Talk::Transcript::CueList.from_youtube(youtube_transcript)
    generated = youtube_transcript.is_generated
    segments = talk.child_talks.where(video_provider: "parent")

    if segments.any?
      segments.each { |child| store_slice(child, language, raw, generated) }
    else
      store(talk, language, raw, generated)
    end
  end

  def store_slice(child, language, raw, generated)
    return unless child.start_seconds && child.end_seconds

    slice = raw.slice(child.start_seconds, child.end_seconds).presence
    return unless slice

    store(child, language, slice, generated)
  end

  def store(talk, language, raw, generated)
    transcript = talk.talk_transcripts.find_or_initialize_by(language: language)

    transcript.update!(raw_transcript: raw, auto_generated: generated)
  end
end
