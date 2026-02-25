module YouTube
  class Client < ApplicationClient
    BASE_URI = "https://youtube.googleapis.com/youtube/v3"

    private

    def all_items(path, query: {})
      response = get(path, query: query.merge({key: token, maxResults: 50}))
      all_items = response.items

      loop do
        next_page_token = response.try(:nextPageToken)
        break if next_page_token.nil?
        response = get(path, query: query.merge({key: token, maxResults: 50, pageToken: next_page_token}))
        all_items += response.items
      end
      all_items
    end

    def default_headers
      {
        "Content-Type" => "application/json"
      }
    end

    def token
      Rails.application.credentials.youtube&.dig(:api_key) || ENV["YOUTUBE_API_KEY"]
    end
  end
end
