# frozen_string_literal: true

class SpeakerSchema < RubyLLM::Schema
  string :name, description: "Full name of the speaker", required: true
  string :slug, description: "URL-friendly slug for the speaker", required: true
  string :github, description: "GitHub username", required: true

  string :twitter, description: "Twitter/X handle (without @)", required: false
  string :website, description: "Personal website URL", required: false
  string :mastodon, description: "Full Mastodon profile URL", required: false
  string :bluesky, description: "Bluesky handle", required: false
  string :linkedin, description: "LinkedIn profile URL", required: false
  string :speakerdeck, description: "Speakerdeck profile URL", required: false

  array :aliases, description: "Alternative names for the speaker", required: false do
    object do
      string :name, required: true
      string :slug, required: true
    end
  end

  string :canonical_slug, description: "Slug of the canonical speaker profile (for deduplication)", required: false
end
