module MarkdownPresenters
  # Renders `/llms.txt`: a curated, llmstxt.org-style entry point that points AI
  # tools at the main sections, recent talks, and the full machine index.
  class LlmsIndex < BasePresenter
    RECENT_TALKS = 30

    def to_text
      [
        "# RubyEvents",
        summary,
        markdown_note,
        browse_section,
        recent_section,
        full_index_section
      ].compact_blank.join("\n\n") + "\n"
    end

    private

    def summary
      "> RubyEvents is the open source community archive of Ruby conference and " \
        "meetup talks: #{Talk.count}+ recorded talks across #{Event.count}+ events, " \
        "with speakers, topics, summaries, and transcripts. The content is MIT-licensed."
    end

    def markdown_note
      "Every talk, speaker, event, and topic page has a Markdown version at the " \
        "same URL with a `.md` suffix (for example, `https://www.rubyevents.org/talks/some-talk.md`). " \
        "Pages also respond to `Accept: text/markdown` content negotiation."
    end

    def browse_section
      <<~SECTION.strip
        ## Browse

        - #{link("All talks", talks_url)}: Searchable index of every recorded Ruby talk
        - #{link("Speakers", speakers_url)}: Profiles of Ruby speakers and their talks
        - #{link("Events", events_url)}: Ruby conferences and meetups
        - #{link("Topics", topics_url)}: Talks grouped by topic and gem
      SECTION
    end

    def recent_section
      talks = Talk.includes(:speakers, :event).where.not(date: nil).order(date: :desc).limit(RECENT_TALKS)
      return if talks.empty?

      lines = talks.map do |talk|
        meta = [talk.speakers.map(&:name).join(", "), talk.event&.name].compact_blank.join(", ")
        "- #{link(talk.title, talk_url(talk, format: :md))}: #{meta}"
      end

      "## Recent talks\n\n#{lines.join("\n")}"
    end

    def full_index_section
      "## Full index\n\n- #{link("Complete talk index", "#{HOST}/llms-full.txt")}: " \
        "Every talk with a link to its Markdown version"
    end
  end
end
