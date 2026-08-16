module YouTube
  class Video < Client
    def available?(video_id)
      path = "/videos"
      query = {
        part: "status",
        id: video_id
      }

      response = all_items(path, query: query)
      response.present?
    end

    def get_statistics(video_id)
      path = "/videos"
      query = {
        part: "statistics",
        id: video_id
      }

      response = all_items(path, query: query)

      return unless response.present?

      response.each_with_object({}) do |item, hash|
        hash[item["id"]] = {
          view_count: item["statistics"]["viewCount"],
          like_count: item["statistics"]["likeCount"]
        }
      end
    end

    def get_channels(video_ids)
      Array(video_ids).each_slice(50).each_with_object({}) do |batch, result|
        items = all_items("/videos", query: {part: "snippet", id: batch.join(",")})

        items.each do |item|
          result[item["id"]] = {
            channel_id: item.dig("snippet", "channelId"),
            channel_title: item.dig("snippet", "channelTitle")
          }
        end
      end
    end

    def get_published_at(video_ids)
      Array(video_ids).each_slice(50).each_with_object({}) do |batch, result|
        items = all_items("/videos", query: {part: "snippet,liveStreamingDetails", id: batch.join(",")})

        items.each do |item|
          published_at = item.dig("liveStreamingDetails", "actualStartTime") || item.dig("snippet", "publishedAt")

          result[item["id"]] = Time.parse(published_at) if published_at
        end
      end
    end

    def duration(video_id)
      path = "/videos"
      query = {
        part: "contentDetails",
        id: video_id
      }

      response = all_items(path, query: query)

      duration_str = response&.first&.dig("contentDetails", "duration")

      return nil unless duration_str

      # Convert ISO 8601 duration (PT1H1M17S) to seconds
      ActiveSupport::Duration.parse(duration_str).to_i
    end
  end
end
