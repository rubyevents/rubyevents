module MarkdownPresenters
  # Renders `/llms-full.txt`: a complete, flat index of every talk with a link to
  # its Markdown version, grouped by event. Heavier than `/llms.txt`, so it is
  # cached and built from plucked columns to keep memory bounded.
  class LlmsFull < BasePresenter
    def to_text
      ([header] + event_sections).join("\n\n") + "\n"
    end

    private

    def header
      "# RubyEvents: complete talk index\n\n" \
        "> Every recorded Ruby talk on RubyEvents (#{Talk.count} talks across " \
        "#{Event.count} events), grouped by event. Each link points to the " \
        "Markdown version of the talk. The content is MIT-licensed."
    end

    def event_sections
      talks_by_event = Talk.includes(:speakers, event: :series).where.not(date: nil).order(date: :desc).group_by(&:event)

      talks_by_event.sort_by { |event, _| event&.start_date || Date.new(0) }.reverse.map do |event, talks|
        heading = event ? link(event.name, event_url(event)) : "Other"
        lines = talks.map { |talk| talk_line(talk) }
        "## #{heading}\n\n#{lines.join("\n")}"
      end
    end

    def talk_line(talk)
      speakers = talk.speakers.map(&:name).join(", ")
      line = "- #{link(talk.title, talk_url(talk, format: :md))}"
      speakers.present? ? "#{line}: #{speakers}" : line
    end
  end
end
