# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkRenamesTest < ActiveSupport::TestCase
  BASELINE = [
    {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
  ].freeze

  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"id" => "x", "title" => "Something"}]) do |path|
      assert Static::Validators::TalkRenames.new(file_path: path).applicable?
    end
  end

  test "does not flag unchanged ids" do
    with_temp_video(BASELINE) do |path|
      assert_empty errors_for(path)
    end
  end

  test "does not flag removed old_ids as long as the id survives" do
    baseline = [
      {"id" => "jane-doe-testconf-2024", "old_id" => "jane-doe-legacy-id", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
    ]
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
    ]

    with_temp_video(videos) do |path|
      assert_empty errors_for(path, baseline: baseline)
    end
  end

  test "does not flag a rename that keeps the previous id as old_id" do
    videos = [
      {"id" => "jane-doe-keynote-testconf-2024", "old_id" => "jane-doe-testconf-2024", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
    ]

    with_temp_video(videos) do |path|
      assert_empty errors_for(path)
    end
  end

  test "flags a rename without old_id and points at the renamed entry" do
    videos = [
      {"id" => "jane-doe-keynote-testconf-2024", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
    ]

    with_temp_video(videos) do |path|
      errors = errors_for(path)

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(id "jane-doe-keynote-testconf-2024" was renamed from "jane-doe-testconf-2024")
      assert_includes errors.first.message, %(`old_id: "jane-doe-testconf-2024"`)
      assert_includes errors.first.message, "bin/rails talk_ids:backfill_old_ids"
    end
  end

  test "renamed_talks maps the renamed entry to its previous id" do
    videos = [
      {"id" => "jane-doe-keynote-testconf-2024", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
    ]

    with_temp_video(videos) do |path|
      baseline_file = Static::VideosFile.parse(BASELINE.to_yaml)
      validator = Static::Validators::TalkRenames.new(file_path: path, baseline: baseline_file)

      assert_equal ["jane-doe-testconf-2024"], validator.renamed_talks.values
      assert_equal "jane-doe-keynote-testconf-2024", validator.renamed_talks.keys.first.value_at("id")
      assert_empty validator.disappeared_ids
    end
  end

  test "flags an id that disappeared entirely" do
    with_temp_video([{"id" => "someone-else-testconf-2024", "title" => "Another Talk"}]) do |path|
      errors = errors_for(path)

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(id "jane-doe-testconf-2024" disappeared from this file)
    end
  end

  test "does not flag an id listed under removed_talk_ids in event.yml" do
    with_temp_video([{"id" => "someone-else-testconf-2024", "title" => "Another Talk"}], removed_talk_ids: ["jane-doe-testconf-2024"]) do |path|
      assert_empty errors_for(path)
    end
  end

  test "still flags a disappeared id when a different id is listed under removed_talk_ids" do
    with_temp_video([{"id" => "someone-else-testconf-2024", "title" => "Another Talk"}], removed_talk_ids: ["somebody-else-testconf-2024"]) do |path|
      errors = errors_for(path)

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(id "jane-doe-testconf-2024" disappeared from this file)
      assert_includes errors.first.message, "`removed_talk_ids` in event.yml"
    end
  end

  test "checks nested talks" do
    baseline = [
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "talks" => [{"id" => "jane-doe-testconf-2024", "title" => "Lightning Talk: A", "video_provider" => "parent", "video_id" => "abc12345678"}]
      }
    ]
    videos = [
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "talks" => [{"id" => "jane-doe-lightning-talk-testconf-2024", "title" => "Lightning Talk: A", "video_provider" => "parent", "video_id" => "abc12345678"}]
      }
    ]

    with_temp_video(videos) do |path|
      errors = errors_for(path, baseline: baseline)

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(was renamed from "jane-doe-testconf-2024")
    end
  end

  test "does not flag re-ordered talks and still matches renames by video_id" do
    baseline = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "video_provider" => "youtube", "video_id" => "abc12345678"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "youtube", "video_id" => "def12345678"}
    ]
    videos = [
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "youtube", "video_id" => "def12345678"},
      {"id" => "jane-doe-keynote-testconf-2024", "title" => "A", "video_provider" => "youtube", "video_id" => "abc12345678"}
    ]

    with_temp_video(videos) do |path|
      errors = errors_for(path, baseline: baseline)

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(id "jane-doe-keynote-testconf-2024" was renamed from "jane-doe-testconf-2024")
    end
  end

  test "skips files without a git baseline" do
    with_temp_video([{"id" => "anything-goes", "title" => "Something"}]) do |path|
      assert_empty Static::Validators::TalkRenames.new(file_path: path).errors
    end
  end

  test "skips a file that git reports as unchanged against the baseline" do
    with_temp_video(RENAMED) do |path|
      with_changed_paths(Set.new) do
        assert_empty Static::Validators::TalkRenames.new(file_path: path).errors
      end
    end
  end

  test "validates a file that git reports as changed against the baseline" do
    with_temp_video(RENAMED) do |path|
      with_changed_paths(Set[path]) do
        errors = Static::Validators::TalkRenames.new(file_path: path).errors

        assert_equal 1, errors.size
        assert_includes errors.first.message, %(was renamed from "jane-doe-testconf-2024")
      end
    end
  end

  test "still validates when an explicit baseline is injected" do
    with_temp_video(RENAMED) do |path|
      with_changed_paths(Set.new) do
        assert_equal 1, errors_for(path).size
      end
    end
  end

  test "checks every file when git cannot resolve a baseline" do
    Static::Validators::TalkRenames.reset!

    Static::Validators::TalkRenames.stub(:baseline_ref, nil) do
      assert_nil Static::Validators::TalkRenames.changed_paths, "a missing baseline must mean check everything, not skip everything"
    end
  ensure
    Static::Validators::TalkRenames.reset!
  end

  private

  RENAMED = [
    {"id" => "jane-doe-keynote-testconf-2024", "title" => "Building Things", "video_provider" => "youtube", "video_id" => "abc12345678"}
  ].freeze

  def with_changed_paths(paths, &block)
    baseline_file = Static::VideosFile.parse(BASELINE.to_yaml)

    Static::Validators::TalkRenames.stub(:changed_paths, paths) do
      Static::Validators::TalkRenames.stub(:baseline_file, baseline_file, &block)
    end
  end

  def errors_for(path, baseline: BASELINE)
    baseline_file = Static::VideosFile.parse(baseline.to_yaml)

    Static::Validators::TalkRenames.new(file_path: path, baseline: baseline_file).errors
  end

  def with_temp_video(videos, removed_talk_ids: nil)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, videos.to_yaml)
    write_event_file(File.dirname(videos_path), removed_talk_ids) if removed_talk_ids
    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end

  def write_event_file(dir, removed_talk_ids)
    lines = ["---", %(id: "testconf-2024"), %(title: "TestConf 2024"), "removed_talk_ids:"]
    lines += removed_talk_ids.map { |id| %(  - "#{id}") }

    File.write(File.join(dir, "event.yml"), lines.join("\n") + "\n")
  end
end
