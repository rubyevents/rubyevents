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
