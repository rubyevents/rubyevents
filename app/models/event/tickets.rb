# frozen_string_literal: true

require "uri"

class Event::Tickets < ActiveRecord::AssociatedObject
  PROVIDERS = {
    "Tito" => ["ti.to", "tito.io"],
    "Luma" => ["lu.ma", "luma.com"],
    "Meetup" => ["meetup.com"],
    "Connpass" => ["connpass.com"],
    "Pretix" => ["pretix.eu"],
    "Eventpop" => ["eventpop.me"],
    "Eventbrite" => ["eventbrite.com", "eventbrite.co.uk"],
    "TicketTailor" => ["tickettailor.com"],
    "Sympla" => ["sympla.com.br"]
  }.freeze

  extension do
    def tickets?
      tickets.exist?
    end

    def next_upcoming_event_with_tickets
      return nil if series.nil?

      series.events
        .upcoming
        .select(&:tickets?)
        .reject { |e| e.id == id }
        .first
    end
  end

  def url
    static_repository&.attributes&.dig("tickets_url")
  end

  def exist?
    url.present?
  end

  def available?
    exist? && event.upcoming?
  end

  def tito_event_slug
    return nil unless tito?

    match = url&.match(%r{(?:ti\.to|tito\.io)/(.+?)/?$})
    match&.captures&.first
  end

  def provider
    @provider ||= ActiveSupport::StringInquirer.new(provider_name.to_s.downcase)
  end

  def provider_name
    PROVIDERS.find { |_, domains| host_is?(*domains) }&.first
  end

  def tito? = provider.tito?
  def luma? = provider.luma?
  def meetup? = provider.meetup?

  private

  def ticket_url_host
    return nil if url.blank?

    URI.parse(url).host&.downcase
  rescue URI::InvalidURIError
    nil
  end

  def host_is?(*domains)
    host = ticket_url_host&.delete_prefix("www.")
    return false if host.nil?

    domains.any? { |domain| host == domain.downcase }
  end

  def static_repository
    @static_repository ||= Static::Event.find_by_slug(event.slug)
  end
end
