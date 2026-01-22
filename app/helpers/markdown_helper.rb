module MarkdownHelper
  def markdown_to_html(markdown_content)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer)
    markdown.render(markdown_content).html_safe
  end

  def announcement_markdown_to_html(markdown_content)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: {target: "_blank", rel: "noopener noreferrer"})
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true)
    html = markdown.render(markdown_content)

    html = process_mentions(html)

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
end
