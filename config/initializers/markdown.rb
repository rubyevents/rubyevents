module Handlers
  class CustomRenderer < Redcarpet::Render::HTML
    # Override the link method to add target="_blank" and rel="noopener noreferrer"
    def link(link, title, content)
      %(<a href="#{link}" target="_blank" rel="noopener noreferrer" #{"title=\"#{title}\"" if title}>#{content}</a>)
    end
  end

  class MarkdownHandler
    def call(template, source)
      # Use the custom renderer instead of the default one
      renderer = CustomRenderer.new
      markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true)
      rendered_content = markdown.render(source)

      # Escape the rendered content to prevent string interpolation issues
      escaped_content = rendered_content.gsub('"', '\"').gsub("\n", "\\n")

      %(
        "<div class='container my-8 markdown max-w-3xl'>#{escaped_content}</div>".html_safe
      )
    end
  end
end

ActionView::Template.register_template_handler :md, Handlers::MarkdownHandler.new
