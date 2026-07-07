# frozen_string_literal: true

class SpeakerSchema < ApplicationSchema
  string :name, description: "Full name of the speaker", required: true
  string :slug, description: "URL-friendly slug for the speaker", required: true
  string :github, description: "GitHub username (not a URL)", required: true, pattern: "^([^/:\\s]+)?$"

  string :twitter, description: "Twitter/X handle (without @, not a URL)", required: false, pattern: "^([^/:\\s]+)?$"
  string :website, description: "Personal website URL", required: false
  string :mastodon, description: "Full Mastodon profile URL (e.g. https://ruby.social/@username)", required: false, pattern: "^(https?://[^/]+/@[^/\\s]+)?$"
  string :bluesky, description: "Bluesky handle (not a URL)", required: false, pattern: "^([^/:\\s]+)?$"
  string :linkedin, description: "LinkedIn username (the part after /in/, not a URL)", required: false, pattern: "^([^/:\\s]+)?$"
  string :speakerdeck, description: "Speakerdeck username (not a URL)", required: false, pattern: "^([^/:\\s]+)?$"

  array :aliases, description: "Alternative names for the speaker", required: false do
    object do
      string :name, required: true
      string :slug, required: true
    end
  end

  string :canonical_slug, description: "Slug of the canonical speaker profile (for deduplication)", required: false
end
