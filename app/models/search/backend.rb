# frozen_string_literal: true

module Search::Backend
  class << self
    attr_writer :default_backend_key

    def backends
      @backends ||= {
        sqlite_fts: Search::Backend::SQLiteFTS,
        typesense: Search::Backend::Typesense
      }.freeze
    end

    def available_backends
      backends.select { |_key, klass| klass.available? }.keys
    end

    def resolve(preferred = nil)
      if preferred && backends.key?(preferred.to_sym)
        backend = backends[preferred.to_sym]
        return backend if backend.available?
      end

      default_backend
    end

    def default_backend
      resolve(default_backend_key)
    end

    def default_backend_key
      return @default_backend_key if @default_backend_key

      if Search::Backend::Typesense.available?
        :typesense
      else
        :sqlite_fts
      end
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
