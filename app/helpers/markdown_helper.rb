module MarkdownHelper
  # Custom renderer with Rouge syntax highlighting
  class SyntaxHighlightedRenderer < Redcarpet::Render::HTML
    def block_code(code, language)
      language ||= "text"
      lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
      formatter = Rouge::Formatters::HTML.new
      highlighted = formatter.format(lexer.lex(code))
      %(<pre class="highlight"><code class="language-#{language}">#{highlighted}</code></pre>)
    end
  end

  def markdown_to_html(markdown_content)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer)
    markdown.render(markdown_content).html_safe
  end

  def announcement_markdown_to_html(markdown_content)
    renderer = SyntaxHighlightedRenderer.new(
      hard_wrap: true,
      link_attributes: {target: "_blank", rel: "noopener noreferrer"}
    )
    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true
    )
    html = markdown.render(markdown_content)

    html = process_mentions(html)
    html = process_topics(html)

    html.html_safe
  end

  private

  def process_mentions(html)
    html.gsub(/@(\w+)/) do |match|
      username = $1
      user = User.find_by_github_handle(username)

      if user
        link_to("@#{username}", profile_path(user), class: "text-primary hover:underline")
      else
        match
      end
    end
  end

  # Topics can be added to the content with the wiki-link syntax
  # [[topic-slug]] - supports hyphenated slugs
  def process_topics(html)
    html.gsub(/\[\[([\w-]+)\]\]/) do |match|
      slug = $1
      topic = Topic.find_by(slug: slug) || Topic.find_by(name: slug)

      if topic
        link_to(topic.name, topic_path(topic), class: "text-primary hover:underline")
      else
        match
      end
    end
  end
end
