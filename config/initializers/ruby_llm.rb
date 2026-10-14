require "ruby_llm"

RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.open_ai&.dig(:access_token) || ENV["OPENAI_ACCESS_TOKEN"] || ENV["OPENAI_API_KEY"] || (Rails.env.test? ? "test" : nil)
  config.openai_organization_id = Rails.application.credentials.open_ai&.dig(:organization_id) || ENV["OPENAI_ORGANIZATION_ID"]
  config.request_timeout = 1800 # with flex tier we can have very long requests
  # config.default_model = "gpt-4.1-nano"
end
