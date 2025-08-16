require "yt"

api_key = Rails.application.credentials.youtube&.dig(:api_key) || ENV["YOUTUBE_API_KEY"]

Yt.configure do |config|
  config.api_key = api_key
end
