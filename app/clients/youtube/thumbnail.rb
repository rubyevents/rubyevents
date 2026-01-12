# frozen_string_literal: true

module YouTube
  class Thumbnail
    SIZES = %w[maxresdefault sddefault hqdefault mqdefault default].freeze
    DEFAULT_MAX_SIZE = 5000
    EXPECTED_ASPECT_RATIO = 16.0 / 9.0
    ASPECT_RATIO_TOLERANCE = 0.1

    SIZE_MAPPING = {
      thumbnail_xl: "maxresdefault",
      thumbnail_lg: "sddefault",
      thumbnail_md: "hqdefault",
      thumbnail_sm: "mqdefault",
      thumbnail_xs: "default"
    }.freeze

    def initialize(video_id)
      @video_id = video_id
    end

    def best_url
      best_url_from("maxresdefault")
    end

    def best_url_for(talk_size)
      starting_size = SIZE_MAPPING[talk_size.to_sym]
      return nil unless starting_size

      best_url_from(starting_size)
    end

    def best_url_from(starting_size)
      start_index = SIZES.index(starting_size) || 0
      candidate_sizes = SIZES[start_index..]

      candidate_sizes.each do |size|
        url = url_for(size)

        next if default?(url)
        next unless valid_aspect_ratio?(url)

        return url
      end

      candidate_sizes.each do |size|
        url = url_for(size)

        return url unless default?(url)
      end

      nil
    end

    def url_for(size)
      "https://i.ytimg.com/vi/#{@video_id}/#{size}.jpg"
    end

    def default?(url)
      content_length(url) < DEFAULT_MAX_SIZE
    rescue => e
      Rails.logger.error("Error checking YouTube thumbnail #{url}: #{e.message}")
      false
    end

    def valid_aspect_ratio?(url)
      uri = URI.parse(url)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 5
        http.read_timeout = 5
        http.request_get(uri.path)
      end

      image = MiniMagick::Image.read(response.body)
      aspect_ratio = image.width.to_f / image.height

      (aspect_ratio - EXPECTED_ASPECT_RATIO).abs < ASPECT_RATIO_TOLERANCE
    rescue => e
      Rails.logger.error("Error checking aspect ratio for #{url}: #{e.message}")
      true
    end

    private

    def content_length(url)
      uri = URI.parse(url)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 5
        http.read_timeout = 5
        http.request_head(uri.path)
      end

      response["Content-Length"].to_i
    end
  end
end
