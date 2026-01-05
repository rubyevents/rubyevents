# frozen_string_literal: true

module Search::Backend
  class << self
    def backends
      @backends ||= {
        sqlite_fts: Search::Backend::SQLiteFTS
      }.freeze
    end

    def resolve(preferred = nil)
      if preferred && backends.key?(preferred.to_sym)
        return backends[preferred.to_sym]
      end

      default_backend
    end

    def default_backend
      Search::Backend::SQLiteFTS
    end

    def index(record)
      backends.each_value do |backend|
        backend.indexer.index(record) if backend.available?
      rescue => e
        Rails.logger.error("Failed to index #{record.class}##{record.id} in #{backend.name}: #{e.message}")
      end
    end

    def remove(record)
      backends.each_value do |backend|
        backend.indexer.remove(record) if backend.available?
      rescue => e
        Rails.logger.error("Failed to remove #{record.class}##{record.id} from #{backend.name}: #{e.message}")
      end
    end

    def reindex_all
      backends.each_value do |backend|
        backend.indexer.reindex_all if backend.available?
      rescue => e
        Rails.logger.error("Failed to reindex all in #{backend.name}: #{e.message}")
      end
    end
  end
end
