# frozen_string_literal: true

require "test_helper"

class Static::TalkLanguageValidatorTest < ActiveSupport::TestCase
  include StaticDataSandbox

  test "does not flag a file where no talk sets a language" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "youtube"}
    ]

    assert_empty language_errors(videos)
  end

  test "does not flag a file where every talk sets a language" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "language" => "Japanese"}
    ]

    assert_empty language_errors(videos)
  end

  test "does not flag a file where every talk is explicitly in English" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "language" => "English"}
    ]

    assert_empty language_errors(videos)
  end

  test "flags talks without a language when another talk sets one" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "Japanese"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "youtube"}
    ]

    assert_equal [["john-smith-testconf-2024", missing_language("john-smith-testconf-2024")]], language_errors(videos)
  end

  test "points at the id of the talk" do
    raw = <<~YAML
      ---
      - id: "jane-doe-testconf-2024"
        title: "A"
        language: "Japanese"

      - id: "john-smith-testconf-2024"
        title: "B"
        video_provider: "youtube"
    YAML

    with_talks(raw) do |talks|
      talk = talks.find_by(id: "john-smith-testconf-2024")
      talk.valid?(:lint)
      error = talk.errors.find { |e| e.message == missing_language(talk.id) }

      assert_equal 6, talk.error_location(error).start_line
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

    assert_equal [["john-smith-testconf-2024", missing_language("john-smith-testconf-2024")]], language_errors(videos)
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

    assert_equal [
      ["john-smith-testconf-2024", missing_language("john-smith-testconf-2024")],
      ["jane-doe-testconf-2024", missing_language("jane-doe-testconf-2024")]
    ], language_errors(videos)
  end

  test "does not flag talks with non-watchable video providers" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "Japanese"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "not_recorded"},
      {"id" => "sam-doe-testconf-2024", "title" => "C", "video_provider" => "scheduled"}
    ]

    assert_empty language_errors(videos)
  end

  test "does not flag non-watchable talks next to explicit English keys" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "A", "language" => "English"},
      {"id" => "john-smith-testconf-2024", "title" => "B", "video_provider" => "not_recorded"}
    ]

    assert_empty language_errors(videos)
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

    assert_empty language_errors(videos)
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

    assert_empty language_errors(videos)
  end

  private

  def missing_language(id)
    %(Other talks in this file already set an explicit "language", so please add one to "#{id}" as well, e.g. `language: "English"`, or run `bin/rails talk_languages:backfill` to detect it from the talk's YouTube captions. That way each talk has an explicit language set.)
  end

  def language_errors(videos)
    with_talks(videos) do |talks|
      talks.flat_map do |talk|
        talk.valid?(:lint)
        talk.errors.full_messages.grep(/already set an explicit "language"/).map { |error| [talk.id, error] }
      end
    end
  end

  def with_talks(videos)
    with_static_data_dir do |root|
      path = File.join(root, "data", "testconf", "testconf-2024", "videos.yml")
      FileUtils.mkdir_p(File.dirname(path))
      videos.is_a?(String) ? File.write(path, videos) : Yerba::Document.from(videos).save_to!(path)

      yield Static::Talk.in_file(path)
    end
  end
end
