# frozen_string_literal: true

Typesense.configuration = {
  nodes: [{
    host: ENV.fetch("TYPESENSE_HOST", "localhost"),
    port: ENV.fetch("TYPESENSE_PORT", "8108"),
    protocol: ENV.fetch("TYPESENSE_PROTOCOL", "http")
  }],
  api_key: ENV.fetch("TYPESENSE_API_KEY", "xyz"),
  connection_timeout_seconds: 2,
  log_level: Rails.env.development? ? :debug : :info,
  pagination_backend: :pagy
}
