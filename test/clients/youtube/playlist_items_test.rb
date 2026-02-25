require "test_helper"

class YouTube::PlaylistItemsTest < ActiveSupport::TestCase
  test "should retreive the playlist of a channel" do
    VCR.use_cassette("youtube/playlist_items/all", match_requests_on: [:method]) do
      items = YouTube::PlaylistItems.new.all(playlist_id: "PLE7tQUdRKcyZYz0O3d9ZDdo0-BkOWhrSk")
      assert items.is_a?(Array)
      assert items.length > 50
    end
  end
end
