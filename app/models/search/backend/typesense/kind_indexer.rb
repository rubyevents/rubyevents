# frozen_string_literal: true

class Search::Backend::Typesense
  class KindIndexer
    COLLECTION_NAME = "kinds"

    TALK_KINDS = {
      "keynote" => {name: "Keynotes", icon: "star", category: "talk"},
      "talk" => {name: "Talks", icon: "microphone", category: "talk"},
      "lightning_talk" => {name: "Lightning Talks", icon: "bolt", category: "talk"},
      "workshop" => {name: "Workshops", icon: "wrench", category: "talk"},
      "panel" => {name: "Panels", icon: "users", category: "talk"},
      "interview" => {name: "Interviews", icon: "comments", category: "talk"},
      "fireside_chat" => {name: "Fireside Chats", icon: "fire", category: "talk"},
      "demo" => {name: "Demos", icon: "desktop", category: "talk"},
      "q_and_a" => {name: "Q&A Sessions", icon: "question-circle", category: "talk"},
      "discussion" => {name: "Discussions", icon: "comment-dots", category: "talk"},
      "podcast" => {name: "Podcasts", icon: "podcast", category: "talk"},
      "gameshow" => {name: "Gameshows", icon: "gamepad", category: "talk"},
      "award" => {name: "Awards", icon: "award", category: "talk"}
    }.freeze

    EVENT_KINDS = {
      "conference" => {name: "Conferences", icon: "building", category: "event"},
      "meetup" => {name: "Meetups", icon: "users", category: "event"},
      "workshop" => {name: "Workshops", icon: "wrench", category: "event"},
      "retreat" => {name: "Retreats", icon: "mountain", category: "event"},
      "hackathon" => {name: "Hackathons", icon: "code", category: "event"},
      "event" => {name: "Events", icon: "calendar", category: "event"}
    }.freeze

    class << self
      def collection_schema
        {
          "name" => COLLECTION_NAME,
          "fields" => [
            {"name" => "id", "type" => "string"},
            {"name" => "slug", "type" => "string"},
            {"name" => "name", "type" => "string"},
            {"name" => "category", "type" => "string", "facet" => true},
            {"name" => "icon", "type" => "string", "optional" => true},
            {"name" => "count", "type" => "int32"}
          ],
          "default_sorting_field" => "count",
          "token_separators" => ["-", "_"]
        }
      end

      def client
        ::Typesense::Client.new(::Typesense.configuration)
      end

      def collection
        client.collections[COLLECTION_NAME]
      end

      def ensure_collection!
        collection.retrieve
      rescue ::Typesense::Error::ObjectNotFound
        client.collections.create(collection_schema)
      end

      def reindex_all
        drop_collection!
        ensure_collection!

        index_talk_kinds
        index_event_kinds

        Rails.logger.info "Typesense: Indexed all kinds"
      end

      def drop_collection!
        collection.delete
      rescue ::Typesense::Error::ObjectNotFound
        # Collection doesn't exist, nothing to delete
      end

      def index_talk_kinds
        documents = build_talk_kind_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} talk kinds"
      end

      def index_event_kinds
        documents = build_event_kind_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} event kinds"
      end

      def search(query, category: nil, limit: 10)
        ensure_collection!

        search_params = {
          q: query.presence || "*",
          query_by: "name,slug",
          per_page: limit,
          sort_by: "_text_match:desc,count:desc"
        }

        search_params[:filter_by] = "category:=#{category}" if category.present?

        result = collection.documents.search(search_params)

        documents = result["hits"].map { |hit| hit["document"].symbolize_keys }
        total = result["found"]

        [documents, total]
      end

      private

      def build_talk_kind_documents
        talk_counts = Talk.group(:kind).count

        TALK_KINDS.map do |slug, data|
          count = talk_counts[slug] || 0

          {
            id: "talk_kind_#{slug}",
            slug: slug,
            name: data[:name],
            category: "talk",
            icon: data[:icon],
            count: count
          }
        end
      end

      def build_event_kind_documents
        event_counts = Event.group(:kind).count

        EVENT_KINDS.map do |slug, data|
          count = event_counts[slug] || 0

          {
            id: "event_kind_#{slug}",
            slug: slug,
            name: data[:name],
            category: "event",
            icon: data[:icon],
            count: count
          }
        end
      end
    end
  end
end
