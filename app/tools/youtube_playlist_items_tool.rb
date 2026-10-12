# frozen_string_literal: true

class YouTubePlaylistItemsTool < RubyLLM::Tool
  description "Fetch YouTube playlist items by playlist ID"
  parameter :id, description: "YouTube playlist id"

  def execute(id:)
    playlist = Yt::Playlist.new(id: id)

    playlist.playlist_items.map { |item| YouTubeVideoTool.new.execute(id: item.snippet.resource_id.try(:[], "videoId")) }
  rescue => e
    {error: e.message}
  end
end
