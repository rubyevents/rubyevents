# frozen_string_literal: true

class Todo < Data.define(:file, :line, :column, :content)
  GITHUB_REPO = "https://github.com/rubyevents/rubyevents"

  def self.all
    for_path(Rails.root.join("data"))
  end

  def self.for_path(path, prefix: nil)
    result = Grepfruit.search(
      regex: /TODO|FIXME/,
      path: path.to_s,
      include: ["*.yml", "*.yaml"],
      truncate: 200
    )

    Array.wrap(result[:matches]).map do |match|
      file = prefix ? "#{prefix}/#{match[:file]}" : match[:file]

      new(
        file: file,
        line: match[:line],
        column: match[:column],
        content: match[:content]
      )
    end
  rescue
    # Ignore errors we don't want to raise if the directory is not found
    []
  end

  def url
    if Rails.env.development? && ActiveSupport::Editor.current
      local_url
    else
      github_url
    end
  end

  def git_ref
    Rails.app.revision || "main"
  end

  def github_url
    result = "#{GITHUB_REPO}/blob/#{git_ref}/data/#{file}"
    result += "#L#{line}" if line

    result
  end

  def local_url
    path = Rails.root.join("data", file).to_s

    ActiveSupport::Editor.current.url_for(path, line || 1)
  end

  def normalized_content
    content
      .to_s
      .gsub(/^#\s*(TODO|FIXME):?\s*/i, "")
      .gsub(/^(TODO|FIXME):?\s*/i, "")
      .strip
  end

  def series_slug
    file.split("/").first
  end

  def event_slug
    parts = file.split("/")

    (parts.size >= 2) ? parts[1] : nil
  end
end
