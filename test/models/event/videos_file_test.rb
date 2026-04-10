require "test_helper"

class Event::VideosFileTest < ActiveSupport::TestCase
  setup do
    @event = events(:future_conference)
  end

  test "file_path returns correct path" do
    expected = Rails.root.join("data", @event.series.slug, @event.slug, "videos.yml")
    assert_equal expected, @event.videos_file.file_path
  end

  test "exist? returns false when file does not exist" do
    assert_not @event.videos_file.exist?
  end

  test "entries returns empty array when file does not exist" do
    assert_equal [], @event.videos_file.entries
  end

  test "ids returns empty array when file does not exist" do
    assert_equal [], @event.videos_file.ids
  end

  test "count returns zero when file does not exist" do
    assert_equal 0, @event.videos_file.count
  end

  test "find_by_id returns nil when file does not exist" do
    assert_nil @event.videos_file.find_by_id("nonexistent")
  end

  test "entries returns parsed YAML content" do
    videos_file = @event.videos_file
    videos = [{"id" => "video1", "title" => "Talk 1"}, {"id" => "video2", "title" => "Talk 2"}]

    with_temp_yaml(videos) do |path|
      videos_file.define_singleton_method(:file_path) { path }
      assert_equal videos, videos_file.entries
    end
  end

  test "ids returns all video ids without child talks" do
    videos_file = @event.videos_file
    videos = [
      {"id" => "video1"},
      {"id" => "video2"},
      {"id" => "video3"}
    ]

    with_temp_yaml(videos) do |path|
      videos_file.define_singleton_method(:file_path) { path }
      assert_equal %w[video1 video2 video3], videos_file.ids(child_talks: false)
    end
  end

  test "ids includes child talk ids when child_talks is true" do
    videos_file = @event.videos_file
    videos = [
      {"id" => "video1", "talks" => [{"id" => "child1"}, {"id" => "child2"}]},
      {"id" => "video2"}
    ]

    with_temp_yaml(videos) do |path|
      videos_file.define_singleton_method(:file_path) { path }
      assert_equal %w[video1 child1 child2 video2], videos_file.ids(child_talks: true)
    end
  end

  test "find_by_id returns matching entry" do
    videos_file = @event.videos_file
    videos = [
      {"id" => "video1", "title" => "Talk 1"},
      {"id" => "video2", "title" => "Talk 2"}
    ]

    with_temp_yaml(videos) do |path|
      videos_file.define_singleton_method(:file_path) { path }
      result = videos_file.find_by_id("video2")
      assert_equal({"id" => "video2", "title" => "Talk 2"}, result)
    end
  end

  test "find_by_id returns nil when not found" do
    videos_file = @event.videos_file
    videos = [{"id" => "video1"}]

    with_temp_yaml(videos) do |path|
      videos_file.define_singleton_method(:file_path) { path }
      assert_nil videos_file.find_by_id("nonexistent")
    end
  end

  test "count returns number of entries" do
    videos_file = @event.videos_file
    videos = [{"id" => "video1"}, {"id" => "video2"}, {"id" => "video3"}]

    with_temp_yaml(videos) do |path|
      videos_file.define_singleton_method(:file_path) { path }
      assert_equal 3, videos_file.count
    end
  end

  private

  def with_temp_yaml(content)
    file = Tempfile.new(["videos", ".yml"])
    file.write(content.to_yaml)
    file.close
    yield Pathname.new(file.path)
  ensure
    file.unlink
  end
end
