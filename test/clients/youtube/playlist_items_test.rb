require "test_helper"

class YouTube::PlaylistItemsTest < ActiveSupport::TestCase
  test "should retreive the playlist of a channel" do
    VCR.use_cassette("youtube/playlist_items/all", match_requests_on: [:method]) do
      items = YouTube::PlaylistItems.new.all(playlist_id: "PLE7tQUdRKcyZYz0O3d9ZDdo0-BkOWhrSk")
      assert items.is_a?(Array)
      assert items.length > 50
    end
  end

  test "published_at is when the video went live, not when it was added to the playlist" do
    VCR.use_cassette("youtube/playlist_items/all", match_requests_on: [:method]) do
      items = YouTube::PlaylistItems.new.all(playlist_id: "PLE7tQUdRKcyZYz0O3d9ZDdo0-BkOWhrSk")

      item = items.find { |i| i.video_id == "-ExPO-FCKQA" }
      assert_equal "2023-03-01T16:00:00Z", item.published_at

      assert_operator items.map(&:published_at).uniq.length, :>, 1,
        "every item got the same published_at, which means the playlist-add time leaked back in"
    end
  end
end
