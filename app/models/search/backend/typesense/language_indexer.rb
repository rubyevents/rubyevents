# frozen_string_literal: true

class Search::Backend::Typesense
  class LanguageIndexer
    COLLECTION_NAME = "languages"

    class << self
      def collection_schema
        {
          "name" => COLLECTION_NAME,
          "fields" => [
            {"name" => "id", "type" => "string"},
            {"name" => "code", "type" => "string"},
            {"name" => "name", "type" => "string"},
            {"name" => "emoji_flag", "type" => "string"},
            {"name" => "talk_count", "type" => "int32"}
          ],
          "default_sorting_field" => "talk_count",
          "token_separators" => ["-", "_"],
          "enable_nested_fields" => false
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
        create_synonyms!
        index_languages

        Rails.logger.info "Typesense: Indexed all languages"
      end

      def create_synonyms!
        synonyms = Language.all_synonyms

        synonyms.each do |id, config|
          collection.synonyms.upsert(id, config)
        end

        Rails.logger.info "Typesense: Created #{synonyms.size} language synonyms"
      rescue => e
        Rails.logger.warn "Typesense: Failed to create language synonyms: #{e.message}"
      end

      def drop_collection!
        collection.delete
      rescue ::Typesense::Error::ObjectNotFound
        # Collection doesn't exist, nothing to delete
      end

      def index_languages
        documents = build_language_documents
        return if documents.empty?

        collection.documents.import(documents, action: "upsert")
        Rails.logger.info "Typesense: Indexed #{documents.size} languages"
      end

      def search(query, limit: 10)
        ensure_collection!

        search_params = {
          q: query.presence || "*",
          query_by: "name,code",
          per_page: limit,
          sort_by: "_text_match:desc,talk_count:desc"
        }

        result = collection.documents.search(search_params)

        documents = result["hits"].map { |hit| hit["document"].symbolize_keys }
        total = result["found"]

        [documents, total]
      end

      private

      def build_language_documents
        languages_with_talks.map do |language_code, talk_count|
          language_name = Language.by_code(language_code)
          next unless language_name

          {
            id: "language_#{language_code}",
            code: language_code,
            name: language_name,
            emoji_flag: Language.emoji_flag(language_code),
            talk_count: talk_count
          }
        end.compact
      end

      def languages_with_talks
        @languages_with_talks ||= Talk.where.not(language: [nil, ""])
          .group(:language)
          .count
      end
    end
  end
end
