require "ruby_llm"

RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  # config.default_model = "gpt-4.1-nano"

  # Enable the new Rails-like API
  config.use_new_acts_as = true
end
