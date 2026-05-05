# frozen_string_literal: true

class YouTubeChannelPlaylistsTool < RubyLLM::Tool
  description "Search for playlists on a YouTube channel by keyword. Useful for finding conference playlists."
  param :channel_id, desc: "YouTube channel ID (starts with UC...)"
  param :query, desc: "Search query to filter playlists (e.g., 'RubyConf', '2024')"
  param :limit, desc: "Maximum number of playlists to return (default: 25)", required: false

  def execute(channel_id:, query:, limit: 25)
    client = YouTube::Playlists.new
    playlists = client.search(channel_id: channel_id, query: query, limit: limit.to_i)

    {
      channel_id: channel_id,
      query: query,
      playlist_count: playlists.size,
      playlists: playlists.map { |p| playlist_to_hash(p) }
    }
  rescue => e
    {error: e.message}
  end

  private

  def playlist_to_hash(playlist)
    {
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      channel_id: playlist.channel_id,
      published_at: playlist.published_at,
      year: playlist.year,
      slug: playlist.slug
    }
  end
end
