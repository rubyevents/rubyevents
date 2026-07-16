# frozen_string_literal: true

class YouTubeChannelSchema < ApplicationSchema
  string :id, description: "YouTube channel ID (starts with UC...)"
  string :name, description: "YouTube channel display name", required: true
  string :handle, description: "YouTube channel handle (e.g. @HelveticRuby)", required: true
  string :playlist_matcher, description: "Pattern to match playlists on this channel", required: false
end
