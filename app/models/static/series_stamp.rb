# frozen_string_literal: true

module Static
  class SeriesStamp < Stamp
    self.path = "app/assets/images/events/:event_series_id/stamp*.webp"

    belongs_to :event_series

    def owner
      event_series
    end

    def has_event?
      true
    end

    def variant
      basename.sub(/\Astamp[_-]?/i, "").presence
    end

    def url_path
      Router.series_path(event_series_id)
    end

    def code
      "#{event_series_id}-#{basename}".upcase
    end

    def name
      label = ["Stamp", variant&.titleize].compact.join(" ")

      "#{event_series&.name.presence || event_series_id.titleize} (#{label})"
    end
  end
end
