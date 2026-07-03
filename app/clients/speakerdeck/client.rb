# frozen_string_literal: true

module Speakerdeck
  class Client < ApplicationClient
    BASE_URI = "https://speakerdeck.com"

    def oembed(url)
      deck_url = normalize_url(url)
      get("/oembed.json", query: {url: deck_url})
    end

    private

    def normalize_url(url)
      if url.start_with?("http://", "https://")
        url
      else
        "#{BASE_URI}/#{url}"
      end
    end

    def authorization_header
      {}
    end
  end
end
