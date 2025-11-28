module YouTube
  class Playlists < YouTube::Client
    DEFAULT_METADATA_PARSER = "YouTube::VideoMetadata"

    def all(channel_id:, title_matcher: nil)
      items = all_items("/playlists", query: {channelId: channel_id, part: "snippet,contentDetails"}).map do |metadata|
        year = metadata.snippet.title.match(/\d{4}/).to_s.presence || DateTime.parse(metadata.snippet.publishedAt).year

        OpenStruct.new({
          id: metadata.id,
          title: metadata.snippet.title,
          location: "Earth",
          description: metadata.snippet.description,
          published_at: DateTime.parse(metadata.snippet.publishedAt).to_date.to_s,
          start_date: "#{year}-xx-xx",
          end_date: "#{year}-xx-xx",
          channel_id: metadata.snippet.channelId,
          year: year,
          videos_count: metadata.contentDetails.itemCount,
          metadata_parser: DEFAULT_METADATA_PARSER,
          slug: metadata.snippet.title.parameterize,
          banner_background: "#081625",
          featured_background: "#000000",
          featured_color: "#FFFFFF"
        })
      end
      items = items.select { |item| item.title.match?(string_to_regex(title_matcher)) } if title_matcher
      items
    end

    private

    def string_to_regex(str)
      Regexp.new(str, "i")
    end
  end
end
