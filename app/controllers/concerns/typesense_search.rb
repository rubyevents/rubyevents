# frozen_string_literal: true

module TypesenseSearch
  extend ActiveSupport::Concern

  HEALTH_CHECK_TIMEOUT = 0.5
  CIRCUIT_BREAKER_TTL = 30

  included do
    helper_method :search_backend
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

  class_methods do
    def typesense_circuit_breaker
      @typesense_circuit_breaker ||= CircuitBreaker.new(ttl: CIRCUIT_BREAKER_TTL)
    end
  end

  private

  def typesense_available?
    if Rails.env.development?
      return false if params[:search_backend] == "sqlite"
      return true if params[:search_backend] == "typesense"

      return false
    end

    return false if Rails.env.test?

    self.class.typesense_circuit_breaker.call do
      Timeout.timeout(HEALTH_CHECK_TIMEOUT) do
        Typesense.client.health.retrieve.present?
      end
    end
  end

  def search_backend
    return nil unless search_query.present?

    typesense_available? ? :typesense : :sqlite_fts
  end
end
