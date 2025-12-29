# frozen_string_literal: true

Geocoder.configure(
  lookup: :google,
  api_key: ENV["GEOLOCATE_API_KEY"],
  timeout: 5,
  use_https: true
)
