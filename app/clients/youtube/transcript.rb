module YouTube
  class Transcript
    def self.get(video_id, languages: ["en"])
      new.get(video_id, languages:)
    end

    def get(video_id, languages: ["en"])
      YoutubeRb::Transcript::YouTubeTranscriptApi.new.fetch(video_id, languages:)
    rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript
      nil
    end
  end
end
