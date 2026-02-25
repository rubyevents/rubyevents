# frozen_string_literal: true

class TypesenseIndexJob < ApplicationJob
  queue_as :default

  def perform(record, method)
    return unless record.present?
    return unless record.respond_to?(method)
    return unless Search::Backend::Typesense.available?

    record.send(method)
  rescue Typesense::Error::ObjectNotFound => e
    Rails.logger.warn("TypesenseIndexJob: Object not found - #{e.message}")
  rescue Typesense::Error::RequestMalformed => e
    Rails.logger.error("TypesenseIndexJob: Request malformed - #{e.message}")
  rescue Typesense::Error::ServerError => e
    Rails.logger.error("TypesenseIndexJob: Server error - #{e.message}")

    raise
  end
end
