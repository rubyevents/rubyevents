# frozen_string_literal: true

class Search::Backend::Typesense
  class Indexer
    class << self
      def index(record)
        return unless should_index?(record)

        if record.is_a?(City)
          LocationIndexer.index_city(record)
        else
          record.typesense_index!
        end
      end

      def remove(record)
        if record.is_a?(City)
          LocationIndexer.remove_city(record)
        else
          record.typesense_remove_from_index!
        end
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
        reindex_locations
        reindex_kinds
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

      def reindex_locations
        LocationIndexer.reindex_all
      end

      def reindex_kinds
        KindIndexer.reindex_all
      end

      private

      def should_index?(record)
        return true if record.is_a?(City)
        return false unless record.respond_to?(:typesense_index!)

        record.respond_to?(:should_index?) ? record.should_index? : true
      end
    end
  end
end
