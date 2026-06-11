module MarkdownPresenters
  class TopicPresenter < BasePresenter
    def initialize(topic)
      @topic = topic
    end

    def to_markdown
      [
        "# #{@topic.name}",
        lead(@topic.description) && "> #{lead(@topic.description)}",
        talks_section,
        footer
      ].compact_blank.join("\n\n") + "\n"
    end

    private

    def talks_section
      talks = @topic.talks.includes(:speakers, event: :series).order(date: :desc)
      return if talks.empty?

      lines = talks.map do |talk|
        meta = [talk.speakers.map(&:name).join(", "), talk.event&.name].compact_blank.join(", ")
        line = "- #{link(talk.title, talk_url(talk, format: :md))}"
        meta.present? ? "#{line}: #{meta}" : line
      end

      "## Talks (#{talks.size})\n\n#{lines.join("\n")}"
    end

    def footer
      "---\n\n#{link("View this topic on RubyEvents", topic_url(@topic))}"
    end
  end
end
