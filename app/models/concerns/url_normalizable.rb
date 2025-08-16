# frozen_string_literal: true

module UrlNormalizable
  extend ActiveSupport::Concern

  def self.normalize_url_string(url)
    return "" if url.blank?

    value = url.strip
    value = "https://#{value}" unless value.start_with?("http://", "https://")

    begin
      uri = URI.parse(value)
      # Strip query params and fragment identifiers
      uri.query = nil
      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      value
    end
  end

  class_methods do
    def normalize_url(field)
      normalizes field, with: ->(url) {
        UrlNormalizable.normalize_url_string(url)
      }
    end
  end
end
