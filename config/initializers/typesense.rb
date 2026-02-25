# frozen_string_literal: true

# Typesense Cloud configuration with Search Delivery Network (SDN) support
#
# For local development (single node):
#   TYPESENSE_HOST=localhost
#   TYPESENSE_PORT=8108
#   TYPESENSE_PROTOCOL=http
#   TYPESENSE_API_KEY=xyz
#
# For Typesense Cloud with SDN (multiple nodes):
#   TYPESENSE_NEAREST_NODE=xxx.a1.typesense.net
#   TYPESENSE_NODES=xxx-1.a1.typesense.net,xxx-2.a1.typesense.net,xxx-3.a1.typesense.net
#   TYPESENSE_PORT=443
#   TYPESENSE_PROTOCOL=https
#   TYPESENSE_API_KEY=your-api-key

typesense_config = {
  api_key: ENV.fetch("TYPESENSE_API_KEY", "xyz"),
  connection_timeout_seconds: 2,
  log_level: Rails.env.development? ? :debug : :info,
  pagination_backend: :pagy
}

if ENV["TYPESENSE_NODES"].present?
  port = ENV.fetch("TYPESENSE_PORT", "443").to_i
  protocol = ENV.fetch("TYPESENSE_PROTOCOL", "https")

  typesense_config[:nodes] = ENV["TYPESENSE_NODES"].split(",").map do |host|
    {host: host.strip, port: port, protocol: protocol}
  end

  if ENV["TYPESENSE_NEAREST_NODE"].present?
    typesense_config[:nearest_node] = {
      host: ENV["TYPESENSE_NEAREST_NODE"],
      port: port,
      protocol: protocol
    }
  end
else
  typesense_config[:nodes] = [{
    host: ENV.fetch("TYPESENSE_HOST", "localhost"),
    port: ENV.fetch("TYPESENSE_PORT", "8108").to_i,
    protocol: ENV.fetch("TYPESENSE_PROTOCOL", "http")
  }]
end

Typesense.configuration = typesense_config
