# frozen_string_literal: true

class YouTubeChannelVideosTool < RubyLLM::Tool
  description "Fetch recent videos from a YouTube channel by channel ID. Useful for finding new conference uploads."
  param :channel_id, desc: "YouTube channel ID (starts with UC...)"
  param :limit, desc: "Maximum number of videos to return (default: 25)", required: false

  def execute(channel_id:, limit: 25)
    channel = Yt::Channel.new(id: channel_id)

    videos = channel.videos.take(limit.to_i).map do |video|
      YouTubeVideoTool.video_to_hash(video)
    end

    {
      channel_id: channel.id,
      channel_title: channel.title,
      video_count: videos.size,
      videos: videos
    }
  rescue => e
    {error: e.message}
  end
end
