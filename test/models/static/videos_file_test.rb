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

  test "at returns the file as it was committed at the given timestamp" do
    with_temp_video(VIDEOS) do |file|
      old_videos = [{"id" => "old-testconf-2024", "title" => "Old Title"}]

      with_history(file, "2024-01-15T12:00:00Z" => old_videos, "2024-03-15T12:00:00Z" => VIDEOS)

      assert_equal ["old-testconf-2024"], file.at(Time.utc(2024, 2, 1)).ids
      assert_equal file.ids, file.at(Time.utc(2024, 4, 1)).ids
      assert_nil file.at(Time.utc(2023, 1, 1))
    end
  end

  test "changes lists talks added, removed and modified since a timestamp" do
    with_temp_video(VIDEOS) do |file|
      old_videos = [
        {"id" => "jane-doe-testconf-2024", "title" => "Old Title"},
        {"id" => "retracted-testconf-2024", "title" => "Retracted"}
      ]

      with_history(file, "2024-01-15T12:00:00Z" => old_videos, "2024-03-15T12:00:00Z" => VIDEOS)

      changes = file.changes(Time.utc(2024, 2, 1))

      assert_equal ["lightning-talks-testconf-2024", "one-testconf-2024", "two-testconf-2024"], changes[:added]
      assert_equal ["retracted-testconf-2024"], changes[:removed]
      assert_equal({"jane-doe-testconf-2024" => {"title" => ["Old Title", "Building Things"]}}, changes[:modified])

      assert_nil file.changes(Time.utc(2023, 1, 1))

      assert_equal changes[:added], file.added_videos(Time.utc(2024, 2, 1))
      assert_equal file.ids, file.added_videos(Time.utc(2023, 1, 1))
    end
  end

  test "newly_watchable_videos lists talks whose provider became watchable" do
    current = [
      {"id" => "a-testconf-2024", "title" => "A", "video_provider" => "youtube"},
      {"id" => "b-testconf-2024", "title" => "B"},
      {"id" => "c-testconf-2024", "title" => "C", "video_provider" => "not_recorded"},
      {"id" => "d-testconf-2024", "title" => "D", "video_provider" => "vimeo"}
    ]

    old_videos = [
      {"id" => "a-testconf-2024", "title" => "A", "video_provider" => "scheduled"},
      {"id" => "b-testconf-2024", "title" => "B", "video_provider" => "scheduled"},
      {"id" => "c-testconf-2024", "title" => "C", "video_provider" => "scheduled"},
      {"id" => "d-testconf-2024", "title" => "D", "video_provider" => "vimeo"}
    ]

    with_temp_video(current) do |file|
      with_history(file, "2024-01-15T12:00:00Z" => old_videos, "2024-03-15T12:00:00Z" => current)

      assert_equal ["a-testconf-2024", "b-testconf-2024"], file.newly_watchable_videos(Time.utc(2024, 2, 1))
      assert_empty file.newly_watchable_videos(Time.utc(2023, 1, 1))
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

  def with_history(file, versions)
    repo = file.path.sub(%r{/data/testconf/testconf-2024/videos\.yml\z}, "")
    git(repo, "init")

    versions.each do |date, videos|
      File.write(file.path, videos.to_yaml)
      git(repo, "add", ".")
      commit(repo, "version at #{date}", date)
    end
  end

  def git(repo, *args, env: {})
    assert system(env, "git", "-C", repo, *args, out: File::NULL, err: File::NULL), "git #{args.join(" ")} failed"
  end

  def commit(repo, message, date)
    git(
      repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "-c", "commit.gpgsign=false", "commit", "-m", message,
      env: {"GIT_AUTHOR_DATE" => date, "GIT_COMMITTER_DATE" => date}
    )
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
