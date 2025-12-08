OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.open_ai&.dig(:access_token) || ENV["OPENAI_ACCESS_TOKEN"]
  config.organization_id = Rails.application.credentials.open_ai&.dig(:organization_id) || ENV["OPENAI_ORGANIZATION_ID"]
  config.log_errors = Rails.env.development?
  config.request_timeout = 1800 # with flex tier we can have very long requests
end
