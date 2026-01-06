# frozen_string_literal: true

class GeocoderCacheStore
  def [](key)
    GeocodeResult.find_by(query: normalize_key(key))&.response_body
  end

  def []=(key, value)
    normalized_key = normalize_key(key)
    return if normalized_key.blank? || value.blank?

    GeocodeResult.find_or_initialize_by(query: normalized_key).update!(
      response_body: value.to_s
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "GeocodeResult::CacheStore failed to cache: #{e.message}"

    nil
  end

  def del(key)
    GeocodeResult.where(query: normalize_key(key)).destroy_all
  end

  def keys
    GeocodeResult.pluck(:query)
  end

  alias_method :read, :[]
  alias_method :get, :[]
  alias_method :write, :[]=
  alias_method :set, :[]=
  alias_method :delete, :del

  private

  def normalize_key(key)
    key.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end

Geocoder.configure(
  lookup: :google,
  api_key: ENV["GEOLOCATE_API_KEY"],
  timeout: 5,
  use_https: true,
  cache: GeocoderCacheStore.new
)
