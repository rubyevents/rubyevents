module YouTube
  class Transcript
    def self.get(video_id)
      new.get(video_id)
    end

    def get(video_id)
      YoutubeRb::Transcript::YouTubeTranscriptApi.new.fetch(video_id)
    rescue YoutubeRb::Transcript::CouldNotRetrieveTranscript
      nil
    end
  end
end
