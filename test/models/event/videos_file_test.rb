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

  test "entries returns parsed YAML content" do
    videos_file = @event.videos_file
    videos = [{"id" => "video1", "title" => "Talk 1"}, {"id" => "video2", "title" => "Talk 2"}]

    with_static_event(videos) do |static_event|
      videos_file.define_singleton_method(:static_event) { static_event }
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

    with_static_event(videos) do |static_event|
      videos_file.define_singleton_method(:static_event) { static_event }
      assert_equal %w[video1 video2 video3], videos_file.ids(child_talks: false)
    end
  end

  test "ids includes child talk ids when child_talks is true" do
    videos_file = @event.videos_file
    videos = [
      {"id" => "video1", "talks" => [{"id" => "child1"}, {"id" => "child2"}]},
      {"id" => "video2"}
    ]

    with_static_event(videos) do |static_event|
      videos_file.define_singleton_method(:static_event) { static_event }
      assert_equal %w[video1 child1 child2 video2], videos_file.ids(child_talks: true)
    end
  end

  private

  def with_static_event(videos)
    Dir.mktmpdir do |dir|
      event_path = File.join(dir, "event.yml")

      Yerba::Document.from({"id" => File.basename(dir)}).save_to!(event_path)
      Yerba::Document.from(videos).save_to!(File.join(dir, "videos.yml"))

      yield Static::Event.new(document: Yerba.parse_file(event_path))
    end
  end
end
