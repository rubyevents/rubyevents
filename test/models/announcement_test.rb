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

class AnnouncementCollectionTest < ActiveSupport::TestCase
  def setup
    @published_ruby = Announcement.new(
      title: "Ruby News",
      slug: "ruby-news",
      date: Date.today,
      published: true,
      tags: ["ruby", "news"]
    )
    @published_rails = Announcement.new(
      title: "Rails Update",
      slug: "rails-update",
      date: Date.today - 1,
      published: true,
      tags: ["rails", "news"]
    )
    @draft_ruby = Announcement.new(
      title: "Draft Ruby Post",
      slug: "draft-ruby",
      date: Date.today,
      published: false,
      tags: ["ruby", "draft"]
    )
    @no_tags = Announcement.new(
      title: "No Tags Post",
      slug: "no-tags",
      date: Date.today,
      published: true,
      tags: []
    )

    @collection = Announcement::Collection.new([@published_ruby, @published_rails, @draft_ruby, @no_tags])
  end

  test "Collection is an Array subclass" do
    assert_kind_of Array, @collection
  end

  test "published returns only published announcements" do
    result = @collection.published

    assert_kind_of Announcement::Collection, result
    assert_equal 3, result.size
    assert result.all?(&:published?)
    assert_includes result, @published_ruby
    assert_includes result, @published_rails
    assert_includes result, @no_tags
    refute_includes result, @draft_ruby
  end

  test "by_tag filters announcements by tag" do
    result = @collection.by_tag("ruby")

    assert_kind_of Announcement::Collection, result
    assert_equal 2, result.size
    assert_includes result, @published_ruby
    assert_includes result, @draft_ruby
  end

  test "by_tag is case insensitive" do
    result_lower = @collection.by_tag("ruby")
    result_upper = @collection.by_tag("RUBY")
    result_mixed = @collection.by_tag("Ruby")

    assert_equal result_lower.size, result_upper.size
    assert_equal result_lower.size, result_mixed.size
  end

  test "by_tag returns empty collection when no matches" do
    result = @collection.by_tag("nonexistent")

    assert_kind_of Announcement::Collection, result
    assert_empty result
  end

  test "all_tags returns unique sorted tags" do
    result = @collection.all_tags

    assert_equal ["draft", "news", "rails", "ruby"], result
  end

  test "all_tags returns empty array when no tags" do
    collection = Announcement::Collection.new([@no_tags])
    result = collection.all_tags

    assert_equal [], result
  end

  test "scopes can be chained: published.by_tag" do
    result = @collection.published.by_tag("ruby")

    assert_kind_of Announcement::Collection, result
    assert_equal 1, result.size
    assert_includes result, @published_ruby
    refute_includes result, @draft_ruby
  end

  test "scopes can be chained: by_tag.published" do
    result = @collection.by_tag("ruby").published

    assert_kind_of Announcement::Collection, result
    assert_equal 1, result.size
    assert_includes result, @published_ruby
  end

  test "scopes can be chained: published.by_tag.all_tags" do
    result = @collection.published.by_tag("news").all_tags

    assert_equal ["news", "rails", "ruby"], result
  end

  test "chaining multiple by_tag narrows results" do
    result = @collection.by_tag("ruby").by_tag("news")

    assert_equal 1, result.size
    assert_includes result, @published_ruby
  end

  test "find_by_slug returns announcement with matching slug" do
    result = @collection.find_by_slug("ruby-news")

    assert_equal @published_ruby, result
  end

  test "find_by_slug returns nil when not found" do
    result = @collection.find_by_slug("nonexistent")

    assert_nil result
  end

  test "find_by_slug! returns announcement with matching slug" do
    result = @collection.find_by_slug!("ruby-news")

    assert_equal @published_ruby, result
  end

  test "find_by_slug! raises error when not found" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @collection.find_by_slug!("nonexistent")
    end
  end

  test "published.find_by_slug finds published announcement" do
    result = @collection.published.find_by_slug("ruby-news")

    assert_equal @published_ruby, result
  end

  test "published.find_by_slug returns nil for draft" do
    result = @collection.published.find_by_slug("draft-ruby")

    assert_nil result
  end

  test "by_tag.find_by_slug! chains correctly" do
    result = @collection.by_tag("news").find_by_slug!("rails-update")

    assert_equal @published_rails, result
  end
end
