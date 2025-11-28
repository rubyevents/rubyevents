require "rss"
require "httparty"

class User::SpeakerdeckFeed < ActiveRecord::AssociatedObject
  def username
    user.speakerdeck
  end

  def has_feed?
    username.present?
  end

  def feed
    return nil unless has_feed?

    @feed ||= FeedData.new(username)
  end

  def decks
    return [] unless feed

    feed.decks
  end

  def unused_decks
    return [] unless feed

    feed.find_unused_decks
  end

  private

  class FeedData
    attr_reader :username

    def initialize(username)
      @username = username
      @decks = []
      @feed_fetched = false
    end

    def fetch!
      return self if @feed_fetched

      rss_url = "https://speakerdeck.com/#{@username}.rss"
      response = HTTParty.get(rss_url)
      rss = RSS::Parser.parse(response.body, false)

      if rss&.items
        @decks = rss.items.map { |item| Deck.new(item) }
      end

      @feed_fetched = true
      self
    rescue HTTParty::Error, Net::HTTPError, SocketError, Timeout::Error => e
      Rails.logger.error "Failed to fetch Speakerdeck feed for #{username}: #{e.message}"
      @decks = []
      @feed_fetched = true
      self
    rescue RSS::NotWellFormedError => e
      Rails.logger.error "Invalid RSS feed format for #{username}: #{e.message}"
      @decks = []
      @feed_fetched = true
      self
    end

    def decks
      fetch! unless @feed_fetched

      @decks
    end

    def decks_count
      fetch! unless @feed_fetched

      @decks.size
    end

    def find_unused_decks
      fetch! unless @feed_fetched

      used_urls = Talk.where.not(slides_url: [nil, ""]).pluck(:slides_url)

      @decks.reject { |deck| used_urls.include?(deck.url) }
    end
  end

  class Deck
    attr_reader :title, :url, :description, :published_at, :item

    def initialize(rss_item)
      @item = rss_item
      @title = rss_item.title
      @url = rss_item.link
      @description = rss_item.description
      @published_at = rss_item.pubDate
    end

    def to_h
      {
        item: item,
        title: title,
        url: url,
        description: description,
        published_at: published_at
      }
    end
  end
end
