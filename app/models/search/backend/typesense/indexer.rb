# frozen_string_literal: true

class Search::Backend::Typesense
  class Indexer
    class << self
      def index(record)
        return unless should_index?(record)

        record.typesense_index!
      end

      def remove(record)
        record.typesense_remove_from_index!
      rescue ::Typesense::Error::ObjectNotFound
        # Already removed
      end

      def reindex_all
        reindex_talks
        reindex_users
        reindex_events
        reindex_topics
        reindex_series
        reindex_organizations
        reindex_languages
      end

      def reindex_talks
        Talk.typesense_reindex!
      end

      def reindex_users
        User.typesense_reindex!
      end

      def reindex_events
        Event.typesense_reindex!
      end

      def reindex_topics
        Topic.typesense_reindex!
      end

      def reindex_series
        EventSeries.typesense_reindex!
      end

      def reindex_organizations
        Organization.typesense_reindex!
      end

      def reindex_languages
        LanguageIndexer.reindex_all
      end

      private

      def should_index?(record)
        record.respond_to?(:should_index?) ? record.should_index? : true
      end
    end
  end
end
