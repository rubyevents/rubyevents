# frozen_string_literal: true

class YouTubeVideosTool < RubyLLM::Tool
  description "Fetch YouTube video metadata for multiple videos by their IDs (up to 50 at a time)"
  param :ids, desc: "Comma-separated YouTube video IDs (e.g., 'abc123,def456,ghi789')"

  def execute(ids:)
    video_ids = ids.split(",").map(&:strip).reject(&:empty?).first(50)

    return {error: "No valid video IDs provided"} if video_ids.empty?

    videos = Yt::Collections::Videos.new.where(id: video_ids.join(","))
    videos.map { |video| YouTubeVideoTool.video_to_hash(video) }
  rescue => e
    {error: e.message}
  end
end
