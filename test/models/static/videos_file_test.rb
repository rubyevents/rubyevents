# frozen_string_literal: true

require "test_helper"

class Static::VideosFileTest < ActiveSupport::TestCase
  VIDEOS = [
    {
      "id" => "lightning-talks-testconf-2024",
      "title" => "Lightning Talks",
      "talks" => [
        {"id" => "one-testconf-2024", "title" => "One", "old_id" => "one-legacy"},
        {"id" => "two-testconf-2024", "title" => "Two"}
      ]
    },
    {"id" => "jane-doe-testconf-2024", "title" => "Building Things"}
  ].freeze

  test "video_pairs pairs every video with its nested talks" do
    with_temp_video(VIDEOS) do |file|
      pairs = file.video_pairs

      assert_equal 2, pairs.size
      assert_equal "lightning-talks-testconf-2024", pairs.first.first.value_at("id")
      assert_equal ["one-testconf-2024", "two-testconf-2024"], pairs.first.last.map { |talk| talk.value_at("id") }
      assert_equal "jane-doe-testconf-2024", pairs.last.first.value_at("id")
      assert_empty pairs.last.last
    end
  end

  test "top_level_talks and sub_talks split the pairs" do
    with_temp_video(VIDEOS) do |file|
      assert_equal ["lightning-talks-testconf-2024", "jane-doe-testconf-2024"], file.top_level_talks.map { |node| node.value_at("id") }
      assert_equal ["one-testconf-2024", "two-testconf-2024"], file.sub_talks.map { |node| node.value_at("id") }
    end
  end

  test "talks lists every top-level video before the nested talks" do
    with_temp_video(VIDEOS) do |file|
      assert_equal(
        ["lightning-talks-testconf-2024", "jane-doe-testconf-2024", "one-testconf-2024", "two-testconf-2024"],
        file.talks.map { |node| node.value_at("id") }
      )
    end
  end

  test "nodes follows each video with its own nested talks" do
    with_temp_video(VIDEOS) do |file|
      assert_equal(
        ["lightning-talks-testconf-2024", "one-testconf-2024", "two-testconf-2024", "jane-doe-testconf-2024"],
        file.nodes.map { |node| node.value_at("id") }
      )
    end
  end

  test "ids and old_ids cover nested talks" do
    with_temp_video(VIDEOS) do |file|
      assert_equal(
        ["lightning-talks-testconf-2024", "jane-doe-testconf-2024", "one-testconf-2024", "two-testconf-2024"],
        file.ids
      )
      assert_equal ["one-legacy"], file.old_ids
    end
  end

  test "the node tree is walked once and shared between readers" do
    with_temp_video(VIDEOS) do |file|
      assert_same file.video_pairs, file.video_pairs
      assert_same file.top_level_talks.first, file.nodes.first
      assert_same file.sub_talks.first, file.video_pairs.first.last.first
    end
  end

  test "handles a file with an empty sequence" do
    with_temp_video([]) do |file|
      assert_empty file.video_pairs
      assert_empty file.nodes
      assert_empty file.talks
      assert_empty file.ids
    end
  end

  test "handles a file without a root" do
    with_temp_file("") do |path|
      file = Static::VideosFile.new(path)

      assert_empty file.video_pairs
      assert_empty file.nodes
      assert_empty file.talks
    end
  end

  test "wrap returns an existing VideosFile untouched" do
    with_temp_video(VIDEOS) do |file|
      assert_same file, Static::VideosFile.wrap(file.path, file)
    end
  end

  test "wrap builds a VideosFile around a given document" do
    with_temp_file(VIDEOS.to_yaml) do |path|
      document = Yerba.parse_file(path)
      file = Static::VideosFile.wrap(path, document)

      assert_instance_of Static::VideosFile, file
      assert_same document, file.document
    end
  end

  test "wrap parses the path when no document is given" do
    with_temp_file(VIDEOS.to_yaml) do |path|
      file = Static::VideosFile.wrap(path)

      assert_instance_of Static::VideosFile, file
      assert_equal 2, file.video_pairs.size
    end
  end

  test "delegates unknown methods to the underlying document" do
    with_temp_video(VIDEOS) do |file|
      assert_equal 2, file.root.length
      assert_equal "Lightning Talks", file.to_a.first["title"]
    end
  end

  private

  def with_temp_video(videos, &block)
    with_temp_file(videos.to_yaml) { |path| block.call(Static::VideosFile.new(path)) }
  end

  def with_temp_file(content)
    dir = Dir.mktmpdir
    path = File.join(dir, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    yield path
  ensure
    FileUtils.rm_rf(dir)
  end
end
