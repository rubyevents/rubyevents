module YouTube
  class Transcript
    Track = Data.define(:language_code, :is_generated, :translated, :snippets)

    def self.get(video_id, languages: ["en"])
      new.get(video_id, languages:)
    end

    def get(video_id, languages: ["en"])
      YoutubeRb::Transcript::YouTubeTranscriptApi.new.fetch(video_id, languages:)
    rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript
      nil
    end

    def self.tracks(video_id, languages:)
      new.tracks(video_id, languages:)
    end

    def tracks(video_id, languages:)
      list = api.list(video_id)

      languages.filter_map { |language| track_for(list, language) }.uniq(&:language_code)
    rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript
      []
    end

    private

    def api
      YoutubeRb::Transcript::YouTubeTranscriptApi.new
    end

    def track_for(list, language)
      transcript, translated = resolve(list, language)
      return unless transcript

      fetched = transcript.fetch

      Track.new(
        language_code: fetched.language_code,
        is_generated: transcript.is_generated,
        translated: translated,
        snippets: fetched.snippets
      )
    rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript
      nil
    end

    def resolve(list, language)
      native = native_transcript(list, language)
      return [native, false] if native

      source = list.find(&:translatable?)

      source ? [source.translate(language), true] : [nil, nil]
    end

    def native_transcript(list, language)
      list.find_transcript([language])
    rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript
      nil
    end
  end
end
