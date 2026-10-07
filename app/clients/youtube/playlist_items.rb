module YouTube
  class PlaylistItems < YouTube::Client
    def all(playlist_id:)
      all_items("/playlistItems", query: {playlistId: playlist_id, part: "snippet,contentDetails"}).map do |metadata|
        published_at = metadata.contentDetails&.videoPublishedAt || metadata.snippet.publishedAt

        OpenStruct.new({
          id: metadata.id,
          title: metadata.snippet.title,
          description: metadata.snippet.description,
          published_at: DateTime.parse(published_at).utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          channel_id: metadata.snippet.channelId,
          year: metadata.snippet.title.match(/\d{4}/).to_s.presence || DateTime.parse(published_at).year,
          slug: metadata.snippet.title.parameterize,
          thumbnail_xs: metadata.snippet.thumbnails.default&.url,
          thumbnail_sm: metadata.snippet.thumbnails.medium&.url,
          thumbnail_md: metadata.snippet.thumbnails.high&.url,
          thumbnail_lg: metadata.snippet.thumbnails.standard&.url,
          thumbnail_xl: metadata.snippet.thumbnails.maxres&.url,
          video_provider: "youtube",
          video_id: metadata.contentDetails.videoId
        })
      end
    end
  end
end
