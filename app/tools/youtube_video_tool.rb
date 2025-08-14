# frozen_string_literal: true

class YouTubeVideoTool < RubyLLM::Tool
  description "Fetch YouTube video metadata by video ID"
  param :id, desc: "YouTube video id"

  def execute(id:)
    video = Yt::Video.new(id: id)

    self.class.video_to_hash(video)
  rescue => e
    {error: e.message}
  end

  def self.video_to_hash(video)
    {
      id: video.id,
      title: video.title,
      description: video.description,
      published_at: video.published_at&.to_s,
      channel_id: video.channel_id,
      channel_title: video.channel_title,
      thumbnails: video.thumbnail_url,
      length: video.length,
      duration: video.duration,
      tags: video.tags
    }
  end
end
