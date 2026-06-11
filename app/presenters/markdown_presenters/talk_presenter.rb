module MarkdownPresenters
  class TalkPresenter < BasePresenter
    def initialize(talk)
      @talk = talk
    end

    def to_markdown
      [
        "# #{@talk.title}",
        blockquote,
        metadata,
        summary_section,
        description_section,
        resources_section,
        footer
      ].compact_blank.join("\n\n") + "\n"
    end

    private

    def blockquote
      lead = lead(@talk.summary.presence || @talk.description)
      "> #{lead}" if lead
    end

    def metadata
      list([
        ("- **Speakers:** #{speaker_links}" if @talk.speakers.present?),
        ("- **Event:** #{link(@talk.event.name, event_url(@talk.event))}" if @talk.event),
        ("- **Date:** #{@talk.formatted_date}" if @talk.date),
        ("- **Duration:** #{@talk.formatted_duration}" if @talk.duration),
        ("- **Language:** #{@talk.language_name}" if @talk.language.present?),
        ("- **Topics:** #{topic_links}" if @talk.approved_topics.present?),
        ("- **Video:** #{@talk.provider_url}" if video_url?),
        ("- **Slides:** #{@talk.slides_url}" if @talk.slides_url.present?)
      ])
    end

    def summary_section
      "## Summary\n\n#{@talk.summary}" if @talk.summary.present?
    end

    def description_section
      return if @talk.description.blank? || @talk.description == @talk.summary

      "## Description\n\n#{@talk.description}"
    end

    def resources_section
      resources = Array(@talk.additional_resources).filter_map do |resource|
        url = resource["url"].presence
        next unless url

        "- #{link(resource["name"].presence || url, url)}"
      end
      return if resources.empty?

      "## Resources\n\n#{resources.join("\n")}"
    end

    def footer
      "---\n\n#{link("View this talk on RubyEvents", talk_url(@talk))}"
    end

    def speaker_links
      @talk.speakers.map { |speaker| link(speaker.name, profile_url(speaker)) }.join(", ")
    end

    def topic_links
      @talk.approved_topics.map { |topic| link(topic.name, topic_url(topic)) }.join(", ")
    end

    def video_url?
      @talk.provider_url.present? && @talk.provider_url != "#"
    end
  end
end
