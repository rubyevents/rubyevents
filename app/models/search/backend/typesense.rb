# frozen_string_literal: true

class Search::Backend::Typesense
  HEALTH_CHECK_TIMEOUT = 1.second
  CIRCUIT_BREAKER_TTL = Rails.env.production? ? 5.minutes : 10.seconds

  class << self
    def search_talks(query, limit:, **options)
      search_options = {per_page: limit}.merge(options)
      pagy, talks = Talk.typesense_search_talks(query, search_options)

      [talks, pagy.count]
    end

    def search_talks_with_pagy(query, pagy_backend: nil, **options)
      Talk.typesense_search_talks(query, options)
    end

    def search_speakers(query, limit:)
      pagy, speakers = User.typesense_search_speakers(query, per_page: limit)

      [speakers, pagy.count]
    end

    def search_events(query, limit:)
      pagy, events = Event.typesense_search_events(query, per_page: limit)

      [events, pagy.count]
    end

    def search_topics(query, limit:)
      pagy, topics = Topic.typesense_search_topics(query, per_page: limit)

      [topics, pagy.count]
    end

    def search_series(query, limit:)
      pagy, series = EventSeries.typesense_search_series(query, per_page: limit)

      [series, pagy.count]
    end

    def search_organizations(query, limit:)
      pagy, organizations = Organization.typesense_search_organizations(query, per_page: limit)

      [organizations, pagy.count]
    end

    def search_languages(query, limit:)
      perform_search(:language, query) do
        LanguageIndexer.search(query, limit: limit)
      end
    end

    def search_locations(query, limit:)
      perform_search(:location, query) do
        LocationIndexer.search(query, limit: limit)
      end
    end

    def search_continents(query, limit:)
      perform_search(:continent, query) do
        LocationIndexer.search(query, type: "continent", limit: limit)
      end
    end

    def search_countries(query, limit:)
      perform_search(:country, query) do
        LocationIndexer.search(query, type: "country", limit: limit)
      end
    end

    def search_states(query, limit:)
      perform_search(:state, query) do
        LocationIndexer.search(query, type: "state", limit: limit)
      end
    end

    def search_cities(query, limit:)
      perform_search(:city, query) do
        LocationIndexer.search(query, type: "city", limit: limit)
      end
    end

    def search_kinds(query, limit:)
      perform_search(:kind, query) do
        KindIndexer.search(query, limit: limit)
      end
    end

    def available?
      return false if Rails.env.test?

      circuit_breaker.call do
        Timeout.timeout(HEALTH_CHECK_TIMEOUT) do
          ::Typesense.client.health.retrieve.present?
        end
      end
    end

    def name
      :typesense
    end

    def indexer
      Indexer
    end

    private

    def perform_search(type, query)
      return [[], 0] if query.blank?

      yield
    rescue ::Typesense::Error, Faraday::Error => e
      Rails.logger.warn("Typesense #{type} search failed: #{e.message}")

      [[], 0]
    end

    def circuit_breaker
      @circuit_breaker ||= CircuitBreaker.new(ttl: CIRCUIT_BREAKER_TTL)
    end
  end
end
