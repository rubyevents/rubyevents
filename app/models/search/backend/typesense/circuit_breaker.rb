# frozen_string_literal: true

class Search::Backend::Typesense
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
