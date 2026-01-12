# frozen_string_literal: true

class YouTubePlaylistTool < RubyLLM::Tool
  description "Fetch YouTube playlist metadata by playlist ID"
  param :id, desc: "YouTube playlist id"

  def execute(id:)
    playlist = Yt::Playlist.new(id: id)

    {
      title: playlist.title,
      description: playlist.description,
      channel_id: playlist.channel_id,
      channel_title: playlist.channel_title,
      published_at: playlist.published_at&.to_s,
      items_count: playlist.playlist_items.count
    }
  rescue => e
    {error: e.message}
  end
end
