class ApplicationJob < ActiveJob::Base
  queue_as :low # Most of our jobs aren't time-critical; prefer the ones that are to mark that.

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Apply a catch-all fallback that retries on most exceptions.
  def self.retries(attempts, wait: :polynomially_longer)
    retry_on StandardError, attempts:, wait:
  end
end
