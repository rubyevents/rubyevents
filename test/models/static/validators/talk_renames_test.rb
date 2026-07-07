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

  private

  def errors_for(path, baseline: BASELINE)
    baseline_file = Static::VideosFile.parse(baseline.to_yaml)

    Static::Validators::TalkRenames.new(file_path: path, baseline: baseline_file).errors
  end

  def with_temp_video(videos)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, videos.to_yaml)
    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
