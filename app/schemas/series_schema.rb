# frozen_string_literal: true

class SeriesSchema < RubyLLM::Schema
  string :name, description: "Name of the event series (e.g., 'RailsConf')"
  string :description, description: "Description of the event series", required: false

  string :kind,
    description: "Type of event series",
    enum: ["conference", "meetup", "retreat", "hackathon", "event", "podcast", "online", "organisation"],
    required: false
  string :frequency,
    description: "How often the event occurs",
    enum: ["yearly", "monthly", "weekly", "irregular", "biweekly", "biyearly", "quarterly"],
    required: false
  boolean :ended, description: "Whether the event series has ended", required: false

  string :default_country_code, description: "Default ISO country code (e.g., 'US', 'JP')", required: false

  string :language, description: "Primary language of the event (e.g., 'english', 'japanese')", required: false

  string :website, description: "Official website URL", required: false
  string :original_website, description: "Original/archived website URL", required: false
  string :twitter, description: "Twitter/X handle (without @)", required: false
  string :mastodon, description: "Full Mastodon profile URL", required: false
  string :bsky, description: "Bluesky handle", required: false
  string :github, description: "GitHub organization or repository", required: false
  string :linkedin, description: "LinkedIn page URL", required: false
  string :meetup, description: "Meetup.com group URL", required: false
  string :luma, description: "Luma event URL", required: false
  string :guild, description: "Guild.host URL", required: false
  string :vimeo, description: "Vimeo channel URL", required: false

  string :youtube_channel_id, description: "YouTube channel ID (starts with UC...)", required: false
  string :youtube_channel_name, description: "YouTube channel name", required: false
  string :playlist_matcher, description: "Pattern to match playlists for this series", required: false

  array :aliases, of: :string, description: "Alternative names for the series", required: false
end
