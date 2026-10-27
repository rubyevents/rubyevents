# frozen_string_literal: true

module Static
  class EventStamp < Stamp
    self.path = "app/assets/images/events/:series_id/:event_id/stamp*.webp"

    belongs_to :event
    has_one :series, through: :event

    def owner
      event
    end

    def has_event?
      true
    end

    def variant
      basename.sub(/\Astamp[_-]?/i, "").presence
    end

    def url_path
      Router.event_path(event_id)
    end

    def code
      "#{event_id}-#{basename}".upcase
    end

    def name
      label = ["Stamp", variant&.titleize].compact.join(" ")

      "#{event&.title.presence || event_id.titleize} (#{label})"
    end
  end
end
