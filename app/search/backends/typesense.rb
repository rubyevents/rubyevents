# frozen_string_literal: true

class Backends::Typesense
  HEALTH_CHECK_TIMEOUT = 0.5
  CIRCUIT_BREAKER_TTL = 30

  class << self
    def search_talks(query, limit:)
      pagy, talks = Talk.typesense_search_talks(query, per_page: limit)

      [talks, pagy.count]
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

    # TODO: implement
    # Delegate to SQLiteFTS - no Typesense implementation
    def search_languages(query, limit:)
      ::Backends::SQLiteFTS.search_languages(query, limit: limit)
    end

    def search_locations(query, limit:)
      ::Backends::SQLiteFTS.search_locations(query, limit: limit)
    end

    def available?
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

    def circuit_breaker
      @circuit_breaker ||= CircuitBreaker.new(ttl: CIRCUIT_BREAKER_TTL)
    end
  end

  class CircuitBreaker
    def initialize(ttl:)
      @ttl = ttl
      @state = :closed
      @last_failure_at = nil
      @last_success_at = nil
      @mutex = Mutex.new
    end

    def call
      @mutex.synchronize do
        if @state == :open && @last_failure_at && (Time.now - @last_failure_at) < @ttl
          return false
        end

        if @state == :closed && @last_success_at && (Time.now - @last_success_at) < @ttl
          return true
        end
      end

      result = yield

      @mutex.synchronize do
        @state = :closed
        @last_success_at = Time.now
      end

      result
    rescue
      @mutex.synchronize do
        @state = :open
        @last_failure_at = Time.now
      end

      false
    end
  end
end
