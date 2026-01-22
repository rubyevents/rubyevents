require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "all returns announcements from content directory" do
    announcements = Announcement.all
    assert_kind_of Array, announcements
  end

  test "published filters only published announcements" do
    announcements = Announcement.published
    assert announcements.all?(&:published?)
  end

  test "find_by_slug returns announcement with matching slug" do
    # Create a test announcement file
    announcement = Announcement.all.first
    skip "No announcements in content directory" if announcement.nil?

    found = Announcement.find_by_slug(announcement.slug)
    assert_equal announcement.slug, found.slug
  end

  test "find_by_slug! raises error for missing slug" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Announcement.find_by_slug!("nonexistent-slug")
    end
  end

  test "parses frontmatter correctly" do
    announcement = Announcement.all.first
    skip "No announcements in content directory" if announcement.nil?

    assert announcement.title.present?
    assert announcement.slug.present?
    assert announcement.date.present?
  end

  test "to_param returns slug" do
    announcement = Announcement.all.first
    skip "No announcements in content directory" if announcement.nil?

    assert_equal announcement.slug, announcement.to_param
  end
end
