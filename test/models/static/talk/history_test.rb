# frozen_string_literal: true

require "test_helper"

class Static::Talk::HistoryTest < ActiveSupport::TestCase
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

  test "at returns the file as it was committed at the given timestamp" do
    with_temp_file(VIDEOS.to_yaml) do |path|
      old_videos = [{"id" => "old-testconf-2024", "title" => "Old Title"}]

      with_history(path, "2024-01-15T12:00:00Z" => old_videos, "2024-03-15T12:00:00Z" => VIDEOS)

      history = Static::Talk::History.new(path)

      assert_equal ["old-testconf-2024"], history.at(Time.utc(2024, 2, 1)).ids
      assert_equal Static::Talk.in_file(path).ids, history.at(Time.utc(2024, 4, 1)).ids
      assert_nil history.at(Time.utc(2023, 1, 1))
    end
  end

  test "changes lists talks added, removed and modified since a timestamp" do
    with_temp_file(VIDEOS.to_yaml) do |path|
      old_videos = [
        {"id" => "jane-doe-testconf-2024", "title" => "Old Title"},
        {"id" => "retracted-testconf-2024", "title" => "Retracted"}
      ]

      with_history(path, "2024-01-15T12:00:00Z" => old_videos, "2024-03-15T12:00:00Z" => VIDEOS)

      history = Static::Talk::History.new(path)
      changes = history.changes(Time.utc(2024, 2, 1))

      assert_equal ["lightning-talks-testconf-2024", "one-testconf-2024", "two-testconf-2024"], changes[:added]
      assert_equal ["retracted-testconf-2024"], changes[:removed]
      assert_equal({"jane-doe-testconf-2024" => {"title" => ["Old Title", "Building Things"]}}, changes[:modified])

      assert_nil history.changes(Time.utc(2023, 1, 1))

      assert_equal changes[:added], history.added_talks(Time.utc(2024, 2, 1))
      assert_equal Static::Talk.in_file(path).ids, history.added_talks(Time.utc(2023, 1, 1))
    end
  end

  test "newly_watchable_talks lists talks whose provider became watchable" do
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

    with_temp_file(current.to_yaml) do |path|
      with_history(path, "2024-01-15T12:00:00Z" => old_videos, "2024-03-15T12:00:00Z" => current)

      history = Static::Talk::History.new(path)

      assert_equal ["a-testconf-2024", "b-testconf-2024"], history.newly_watchable_talks(Time.utc(2024, 2, 1))
      assert_empty history.newly_watchable_talks(Time.utc(2023, 1, 1))
    end
  end

  private

  def with_history(path, versions)
    repo = path.sub(%r{/data/testconf/testconf-2024/videos\.yml\z}, "")
    git(repo, "init")

    versions.each do |date, videos|
      File.write(path, videos.to_yaml)
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
