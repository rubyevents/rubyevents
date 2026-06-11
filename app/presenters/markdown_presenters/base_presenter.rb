# Base class for objects that render a model as clean Markdown.
#
# These presenters are the single source of truth for the `.md` versions of
# pages (served both at `/path.md` and via `Accept: text/markdown`) and for the
# `/llms.txt` and `/llms-full.txt` files. They build absolute, canonical URLs so
# the output is portable when copied into an LLM context.
module MarkdownPresenters
  class BasePresenter
    include Rails.application.routes.url_helpers

    HOST = "https://www.rubyevents.org".freeze

    def default_url_options
      {host: HOST}
    end

    private

    def link(text, url)
      "[#{text}](#{url})"
    end

    # First non-empty paragraph, collapsed to a single line for use as a summary.
    def lead(text)
      return nil if text.blank?

      text.to_s.strip.split(/\n{2,}/).first.to_s.squish.presence
    end

    def list(items)
      items.compact_blank.join("\n")
    end
  end
end
