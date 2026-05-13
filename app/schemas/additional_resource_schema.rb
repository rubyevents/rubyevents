# frozen_string_literal: true

class AdditionalResourceSchema < RubyLLM::Schema
  string :name, description: "Display name for the resource", required: true
  string :url, description: "URL to the resource", required: true
  string :type, description: "Type of resource", enum: ["write-up", "blog", "article", "source-code", "code", "repo", "github", "documentation", "docs", "presentation", "video", "podcast", "audio", "gem", "library", "transcript", "handout", "notes", "photos", "link", "book"], required: true
  string :title, description: "Full title of the resource", required: false
end
