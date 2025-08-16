require "test_helper"

class YouTube::PlaylistsTest < ActiveSupport::TestCase
  test "should retreive the playlist of a channel" do
    VCR.use_cassette("youtube/playlists/all", match_requests_on: [:method]) do
      playlists = YouTube::Playlists.new.all(channel_id: "UCWnPjmqvljcafA0z2U1fwKQ")

      assert playlists.is_a?(Array)
      assert playlists.length > 50

      ruby_and_rails_playlists = playlists.filter do |playlist|
        playlist.title.match(/(rails|ruby)/i)
      end

      assert ruby_and_rails_playlists.length < playlists.length
    end
  end
end
