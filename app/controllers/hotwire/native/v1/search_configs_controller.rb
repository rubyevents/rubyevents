# frozen_string_literal: true

module Hotwire
  module Native
    module V1
      class SearchConfigsController < ApplicationController
        skip_before_action :authenticate_user!

        def show
          nodes, nearest = typesense_nodes

          render json: {
            nodes: nodes,
            nearest_node: nearest,
            search_api_key: scoped_search_key,
            per_page: 20,
            talks: Talk.typesense_multi_search_config,
            speakers: User.typesense_multi_search_config,
            events: Event.typesense_multi_search_config
          }
        end

        private

        def typesense_nodes
          port = ENV.fetch("TYPESENSE_PORT", "443").to_i
          protocol = ENV.fetch("TYPESENSE_PROTOCOL", "https")

          if ENV["TYPESENSE_NODES"].present?
            nodes = ENV["TYPESENSE_NODES"].split(",").map { |host| {host: host.strip, port: port, protocol: protocol} }
            nearest = ENV["TYPESENSE_NEAREST_NODE"].presence && {host: ENV["TYPESENSE_NEAREST_NODE"], port: port, protocol: protocol}

            [nodes, nearest]
          else
            single = {host: ENV.fetch("TYPESENSE_HOST", "localhost"), port: ENV.fetch("TYPESENSE_PORT", "8108").to_i, protocol: ENV.fetch("TYPESENSE_PROTOCOL", "http")}

            [[single], nil]
          end
        end

        def scoped_search_key
          parent = ENV["TYPESENSE_SEARCH_ONLY_API_KEY"].presence
          return nil if parent.blank?

          nodes, _ = typesense_nodes
          client = Typesense::Client.new(nodes: nodes, api_key: parent, connection_timeout_seconds: 2)

          client.keys.generate_scoped_search_key(parent, {expires_at: 1.day.from_now.to_i})
        rescue => e
          Rails.logger.warn("Failed to generate scoped search key: #{e.message}")

          nil
        end
      end
    end
  end
end
