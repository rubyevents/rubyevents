# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkLanguageTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"id" => "x", "title" => "Something"}]) do |path|
      assert Static::Validators::TalkLanguage.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::TalkLanguage.new(file_path: file).applicable?
  end

  test "does not flag a file where no talk sets a language" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "youtube"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  test "does not flag a file where every talk sets a language" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "language" => "Japanese"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  test "does not flag a file where every talk is explicitly in English" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "language" => "English"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  test "flags talks without a language when another talk sets one" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "Japanese"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "youtube"}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkLanguage.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_equal %(Other talks in this file already set an explicit "language", so please add one to "john-smith-testconf-2024" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way no talk is left guessing its language.), errors.first.message
    end
  end

  test "flags subtalks without a language when another talk sets one" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "video_provider" => "youtube",
        "language" => "English",
        "talks" => [
          {"id" => "john-smith-testconf-2024", "title" => "Lightning Talk: B", "video_provider" => "parent"}
        ]
      }
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkLanguage.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_equal %(Other talks in this file already set an explicit "language", so please add one to "john-smith-testconf-2024" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way no talk is left guessing its language.), errors.first.message
    end
  end

  test "flags all subtalks without a language when only the parent talk sets one" do
    videos = [
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "video_provider" => "youtube",
        "language" => "Spanish",
        "talks" => [
          {"id" => "john-smith-testconf-2024", "title" => "Lightning Talk: B", "video_provider" => "parent"},
          {"id" => "jane-doe-testconf-2024", "title" => "Lightning Talk: C", "video_provider" => "parent"}
        ]
      }
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkLanguage.new(file_path: path).errors

      assert_equal 2, errors.size
      assert_equal %(Other talks in this file already set an explicit "language", so please add one to "john-smith-testconf-2024" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way no talk is left guessing its language.), errors.first.message
      assert_equal %(Other talks in this file already set an explicit "language", so please add one to "jane-doe-testconf-2024" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way no talk is left guessing its language.), errors.last.message
    end
  end

  test "does not flag talks with non-watchable video providers" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "Japanese"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "not_recorded"},
      {"id" => "sam-doe-testconf-2024", "title" => "C", "video_provider" => "scheduled"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  test "does not flag non-watchable talks next to explicit English keys" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "not_recorded"}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  test "does not flag a sub-talk of a non-watchable parent video" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "Japanese"},
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "video_provider" => "not_recorded",
        "talks" => [
          {"id" => "john-smith-testconf-2024", "title" => "Lightning Talk: B", "video_provider" => "parent"}
        ]
      }
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  test "does not flag a parent talk with sub-talks" do
    videos = [
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "video_provider" => "youtube",
        "talks" => [
          {"id" => "john-smith-testconf-2024", "title" => "Lightning Talk: B", "language" => "Spanish"}
        ]
      }
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkLanguage.new(file_path: path).errors
    end
  end

  private

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
