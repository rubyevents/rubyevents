module MarkdownPresenters
  class EventPresenter < BasePresenter
    def initialize(event)
      @event = event
    end

    def to_markdown
      [
        "# #{@event.name}",
        blockquote,
        metadata,
        talks_section,
        footer
      ].compact_blank.join("\n\n") + "\n"
    end

    private

    def blockquote
      lead = lead(@event.description)
      "> #{lead}" if lead
    end

    def metadata
      list([
        ("- **Location:** #{@event.location}" if @event.location.present?),
        ("- **Dates:** #{@event.formatted_dates}" if @event.start_date),
        ("- **Series:** #{link(@event.series.name, series_url(@event.series))}" if @event.series)
      ]).presence
    end

    def talks_section
      talks = @event.talks.includes(:speakers).order(date: :asc, id: :asc)
      return if talks.empty?

      lines = talks.map do |talk|
        speakers = talk.speakers.map(&:name).join(", ")
        line = "- #{link(talk.title, talk_url(talk, format: :md))}"
        speakers.present? ? "#{line}: #{speakers}" : line
      end

      "## Talks (#{talks.size})\n\n#{lines.join("\n")}"
    end

    def footer
      "---\n\n#{link("View this event on RubyEvents", event_url(@event))}"
    end
  end
end
