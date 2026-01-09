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

google_api_key = ENV["GEOLOCATE_API_KEY"]

if google_api_key.present?
  Geocoder.configure(
    lookup: :google,
    api_key: google_api_key,
    timeout: 5,
    use_https: true,
    cache: GeocoderCacheStore.new
  )
elsif Rails.env.development?
  git_name = `git config user.name 2>/dev/null`.strip.presence

  raise "Nominatim requires contact info. Please set your git user.name" unless git_name

  Geocoder.configure(
    lookup: :nominatim,
    timeout: 5,
    use_https: true,
    cache: GeocoderCacheStore.new,
    http_headers: {"User-Agent" => git_name}
  )
end
