# frozen_string_literal: true

class FeedSourceSchema < RubyLLM::Schema
  string :type, description: "Feed type (ical, rss, bluesky, mastodon, twitter, linkedin)"
  string :url, description: "Feed URL", required: false
  string :name, description: "Display name for this feed", required: false
  string :handle, description: "Account handle (for social feeds)", required: false
  string :account, description: "Full account URL (for Mastodon, etc.)", required: false
end
