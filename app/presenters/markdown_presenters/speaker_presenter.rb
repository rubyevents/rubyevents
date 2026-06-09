module MarkdownPresenters
  class SpeakerPresenter < BasePresenter
    def initialize(user)
      @user = user
    end

    def to_markdown
      [
        "# #{@user.name}",
        blockquote,
        @user.bio.presence,
        links_section,
        talks_section,
        footer
      ].compact_blank.join("\n\n") + "\n"
    end

    private

    def blockquote
      count = @user.talks_count
      "> Ruby speaker with #{count} #{"talk".pluralize(count)} on RubyEvents."
    end

    def links_section
      list([
        ("- **GitHub:** https://github.com/#{@user.github_handle}" if @user.github_handle.present?),
        ("- **X:** https://x.com/#{@user.twitter}" if @user.twitter.present?),
        ("- **Mastodon:** #{@user.mastodon}" if @user.mastodon.present?),
        ("- **LinkedIn:** #{@user.linkedin}" if @user.linkedin.present?),
        ("- **Website:** #{@user.website}" if @user.website.present?)
      ]).presence
    end

    def talks_section
      talks = @user.kept_talks.includes(event: :series).order(date: :desc)
      return if talks.empty?

      lines = talks.map do |talk|
        meta = [talk.event&.name, talk.date && talk.formatted_date].compact_blank.join(", ")
        line = "- #{link(talk.title, talk_url(talk, format: :md))}"
        meta.present? ? "#{line}: #{meta}" : line
      end

      "## Talks (#{talks.size})\n\n#{lines.join("\n")}"
    end

    def footer
      "---\n\n#{link("View this speaker on RubyEvents", profile_url(@user))}"
    end
  end
end
