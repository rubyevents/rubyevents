# frozen_string_literal: true

class SpeakerSchema < RubyLLM::Schema
  string :name, description: "Full name of the speaker"
  string :slug, description: "URL-friendly slug for the speaker"

  string :twitter, description: "Twitter/X handle (without @)", required: false
  string :github, description: "GitHub username", required: false
  string :website, description: "Personal website URL", required: false
  string :mastodon, description: "Full Mastodon profile URL", required: false
  string :bluesky, description: "Bluesky handle", required: false
  string :linkedin, description: "LinkedIn profile URL", required: false

  string :bio, description: "Short biography of the speaker", required: false

  string :canonical_slug, description: "Slug of the canonical speaker profile (for deduplication)", required: false
end
