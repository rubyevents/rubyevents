require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  test "index returns success" do
    get announcements_path
    assert_response :success
  end

  test "show returns success for existing announcement" do
    announcement = Announcement.published.first
    skip "No published announcements" if announcement.nil?

    get announcement_path(announcement.slug)
    assert_response :success
  end

  test "show returns 404 for nonexistent announcement" do
    get announcement_path("nonexistent-slug")
    assert_response :not_found
  end
end
