ActiveGenie.configure do |config|
  config.providers.openai.api_key = Rails.application.credentials.open_ai&.dig(:access_token) || ENV["OPENAI_ACCESS_TOKEN"]
end
