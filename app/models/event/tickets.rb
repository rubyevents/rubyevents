# frozen_string_literal: true

class Event::Tickets < ActiveRecord::AssociatedObject
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

  def provider_name
    return "Tito" if tito?
    return "Luma" if luma?
    return "Meetup" if meetup?
    return "Connpass" if url&.include?("connpass.com")
    return "Pretix" if url&.include?("pretix")
    return "Eventpop" if url&.include?("eventpop")
    return "Eventbrite" if url&.include?("eventbrite")
    return "TicketTailor" if url&.include?("tickettailor")
    return "Sympla" if url&.include?("sympla.com")

    nil
  end

  def tito?
    url&.match?(/ti\.to|tito\.io/)
  end

  def luma?
    url&.match?(/lu\.ma|luma\.com/)
  end

  def meetup?
    url&.include?("meetup.com")
  end

  private

  def static_repository
    @static_repository ||= Static::Event.find_by_slug(event.slug)
  end
end
