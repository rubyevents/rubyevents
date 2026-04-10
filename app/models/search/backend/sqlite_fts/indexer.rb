# frozen_string_literal: true

class Search::Backend::SQLiteFTS
  class Indexer
    class << self
      def index(record)
        case record
        when Talk
          index_talk(record)
        when User
          index_user(record)
        when Event
          index_event(record)
        end
      end

      def remove(record)
        case record
        when Talk
          remove_talk(record)
        when User
          remove_user(record)
        when Event
          remove_event(record)
        end
      end

      def reindex_all
        reindex_talks
        reindex_users
        reindex_events
      end

      def reindex_talks
        Talk::Index.delete_all
        Talk.watchable.find_each do |talk|
          index_talk(talk)
        end
      end

      def reindex_users
        User::Index.delete_all
        User.indexable.find_each do |user|
          index_user(user)
        end
      end

      def reindex_events
        Event::Index.delete_all if defined?(Event::Index)
        # Event indexing if Event::Index exists
      end

      private

      def index_talk(talk)
        return unless talk.video_provider.in?(Talk::WATCHABLE_PROVIDERS)

        talk.fts_index.reindex
      rescue ActiveRecord::RecordNotUnique
        # Already indexed
      end

      def remove_talk(talk)
        Talk::Index.where(rowid: talk.id).delete_all
      end

      def index_user(user)
        return unless user.canonical_id.nil? && user.talks_count.to_i > 0

        user.fts_index.reindex
      rescue ActiveRecord::RecordNotUnique
        # Already indexed
      end

      def remove_user(user)
        User::Index.where(rowid: user.id).delete_all
      end

      def index_event(event)
        # Implement when Event::Index exists
      end

      def remove_event(event)
        # Implement when Event::Index exists
      end
    end
  end
end
