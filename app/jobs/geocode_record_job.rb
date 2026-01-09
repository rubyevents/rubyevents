# frozen_string_literal: true

class GeocodeRecordJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(record) { geocode_concurrency_key(record) }, duration: 1.second

  def perform(record)
    return unless record.geocodeable?

    record.geocode
    record.save!
  end

  def self.geocode_concurrency_key(record)
    if Geocoder.config.lookup == :nominatim
      "geocoding"
    else
      "geocoding:#{record.class.name}:#{record.id}"
    end
  end
end
