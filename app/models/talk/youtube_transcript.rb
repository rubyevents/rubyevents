class Talk::YouTubeTranscript < ActiveRecord::AssociatedObject
  performs :fetch_and_store!, retries: 3

  def available?
    talk.youtube? && talk.video_id.present?
  end

  def fetch
    return unless available?

    YouTube::Transcript.get(talk.video_id)
  end

  def fetch_and_store!
    youtube_transcript = fetch
    return unless youtube_transcript.present?

    transcript = talk.talk_transcript || Talk::Transcript.new(talk: talk)
    transcript.update!(raw_transcript: ::Transcript.create_from_youtube_transcript(youtube_transcript))
  end
end
