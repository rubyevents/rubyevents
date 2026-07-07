# frozen_string_literal: true

class Search::Backend::Typesense
  class TranscriptPassageIndexer
    COLLECTION_NAME = "transcript_passages"
    IMPORT_BATCH_SIZE = 500

    class << self
      def collection_schema
        {
          "name" => COLLECTION_NAME,
          "fields" => [
            {"name" => "talk_id", "type" => "string", "facet" => true},
            {"name" => "talk_slug", "type" => "string"},
            {"name" => "talk_title", "type" => "string"},
            {"name" => "speaker_names", "type" => "string", "optional" => true},
            {"name" => "event_name", "type" => "string", "optional" => true},
            {"name" => "thumbnail", "type" => "string", "optional" => true},
            {"name" => "language", "type" => "string", "facet" => true},
            {"name" => "start_seconds", "type" => "int32"},
            {"name" => "end_seconds", "type" => "int32"},
            {"name" => "text", "type" => "string"},
            {"name" => "watchable", "type" => "bool", "facet" => true},
            {"name" => "date_timestamp", "type" => "int64"}
          ],
          "default_sorting_field" => "date_timestamp",
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

      def drop_collection!
        collection.delete
      rescue ::Typesense::Error::ObjectNotFound
        # Collection doesn't exist, nothing to delete
      end

      def reindex_all
        drop_collection!
        ensure_collection!

        count = 0
        Talk.watchable.includes(:talk_transcripts, :speakers, event: :series).find_each.each_slice(IMPORT_BATCH_SIZE) do |talks|
          documents = talks.flat_map { |talk| build_documents(talk) }
          next if documents.empty?

          collection.documents.import(documents, action: "upsert")
          count += documents.size
        end

        Rails.logger.info "Typesense: Indexed #{count} transcript passages"
        count
      end

      def index_talk(talk)
        ensure_collection!
        remove_talk(talk)

        documents = build_documents(talk)
        collection.documents.import(documents, action: "upsert") if documents.any?
      end

      def remove_talk(talk)
        ensure_collection!
        collection.documents.delete(filter_by: "talk_id:=#{talk.id}")
      rescue ::Typesense::Error::ObjectNotFound
        # Nothing indexed for this talk
      end

      def search(query, limit: 5, page: 1, moments_per_talk: 3)
        return [[], 0, 0] if query.blank?

        ensure_collection!

        result = collection.documents.search(
          q: query,
          query_by: "text",
          filter_by: "watchable:=true",
          group_by: "talk_id",
          group_limit: moments_per_talk,
          per_page: limit,
          page: page,
          highlight_full_fields: "text",
          highlight_affix_num_tokens: 8,
          sort_by: "_text_match:desc,date_timestamp:desc"
        )

        groups = result["grouped_hits"].to_a.map { |group| build_group(group) }

        [groups, result["found"], result["found_docs"]]
      end

      private

      def build_documents(talk)
        watchable = talk.published? || false
        date_timestamp = talk.date&.to_time&.to_i || 0
        speaker_names = talk.speakers.map(&:name).join(", ")

        talk.talk_transcripts.flat_map do |transcript|
          next [] unless transcript.raw_transcript&.present?

          transcript.raw_transcript.passages.map do |passage|
            {
              id: "#{talk.id}-#{transcript.language}-#{passage.start_seconds}",
              talk_id: talk.id.to_s,
              talk_slug: talk.slug,
              talk_title: talk.title,
              speaker_names: speaker_names,
              event_name: talk.event&.name.to_s,
              thumbnail: talk.thumbnail_sm.to_s,
              language: transcript.language,
              start_seconds: passage.start_seconds,
              end_seconds: passage.end_seconds,
              text: passage.text,
              watchable: watchable,
              date_timestamp: date_timestamp
            }
          end
        end
      end

      def build_group(group)
        hits = group["hits"]
        talk = hits.first["document"]

        {
          talk_id: talk["talk_id"],
          talk_slug: talk["talk_slug"],
          talk_title: talk["talk_title"],
          speaker_names: talk["speaker_names"],
          event_name: talk["event_name"],
          thumbnail: talk["thumbnail"],
          moments: hits.map { |hit| build_moment(hit) }.sort_by { |moment| moment[:start_seconds] }
        }
      end

      def build_moment(hit)
        document = hit["document"]
        highlight = hit["highlights"].to_a.find { |entry| entry["field"] == "text" }

        {
          start_seconds: match_timestamp(document, highlight),
          language: document["language"],
          snippet: highlight&.dig("snippet") || document["text"]
        }
      end

      def match_timestamp(document, highlight)
        from = document["start_seconds"].to_i
        full = highlight&.dig("value")
        return from if full.blank?

        words = full.split
        index = words.index { |word| word.include?("<mark>") }
        return from if index.nil? || words.empty?

        to = document["end_seconds"].to_i

        (from + (to - from) * (index.to_f / words.size)).round
      end
    end
  end
end
