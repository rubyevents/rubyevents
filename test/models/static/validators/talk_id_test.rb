# frozen_string_literal: true

require "test_helper"

class Static::Validators::TalkIdTest < ActiveSupport::TestCase
  test "applicable? returns true for a videos.yml file" do
    with_temp_video([{"id" => "x", "title" => "Something"}]) do |path|
      assert Static::Validators::TalkId.new(file_path: path).applicable?
    end
  end

  test "applicable? returns false for an event.yml file" do
    file = Dir.glob(Rails.root.join("data/**/event.yml")).first

    assert_not Static::Validators::TalkId.new(file_path: file).applicable?
  end

  test "does not flag a single speaker talk with a matching id" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "flags a talk whose id does not match firstname-lastname-event-slug" do
    videos = [
      {"id" => "jane-doe-somewhere-else", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(expected id "jane-doe-testconf-2024")
    end
  end

  test "parameterizes accented speaker names" do
    videos = [
      {"id" => "jose-garcia-testconf-2024", "title" => "Hola", "speakers" => ["José García"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "joins two speakers in the id" do
    videos = [
      {"id" => "jane-doe-john-smith-testconf-2024", "title" => "Pairing", "speakers" => ["Jane Doe", "John Smith"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "adds the kind when the same speaker would get a duplicate id" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-lightning-talk-testconf-2024", "title" => "Lightning Talk: Tiny Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "flags a duplicate that is missing the kind" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-2-testconf-2024", "title" => "Keynote: Big Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(expected id "jane-doe-keynote-testconf-2024")
    end
  end

  test "falls back to the title when speaker and kind still collide" do
    videos = [
      {"id" => "jane-doe-building-things-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "jane-doe-breaking-things-testconf-2024", "title" => "Breaking Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert errors.any? { |e| e.message.include?(%(expected id "building-things-testconf-2024")) }
      assert errors.any? { |e| e.message.include?(%(expected id "breaking-things-testconf-2024")) }
    end
  end

  test "numbers ids when speakers, kind and title all collide" do
    videos = [
      {"id" => "building-things-1-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]},
      {"id" => "building-things-2-testconf-2024", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "uses the kind for talks with more than two speakers" do
    videos = [
      {"id" => "panel-testconf-2024", "title" => "Panel: The Future of Ruby", "kind" => "panel", "speakers" => ["A B", "C D", "E F"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "uses the title when multiple speakerless talks share the kind" do
    videos = [
      {"id" => "panel-on-testing-testconf-2024", "title" => "Panel on Testing", "kind" => "panel", "speakers" => ["A B", "C D", "E F"]},
      {"id" => "panel-on-hiring-testconf-2024", "title" => "Panel on Hiring", "kind" => "panel", "speakers" => ["G H", "I J", "K L"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "ignores TODO placeholder speakers and falls back to the title" do
    videos = [
      {"id" => "building-things-testconf-2024", "title" => "Building Things", "speakers" => ["TODO"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "checks nested talks" do
    videos = [
      {
        "id" => "lightning-talk-testconf-2024",
        "title" => "Lightning Talks",
        "kind" => "lightning_talk",
        "talks" => [
          {"id" => "jane-doe-wrong", "title" => "Lightning Talk: Tiny Things", "speakers" => ["Jane Doe"]}
        ]
      }
    ]

    with_temp_video(videos) do |path|
      errors = Static::Validators::TalkId.new(file_path: path).errors

      assert_equal 1, errors.size
      assert_includes errors.first.message, %(expected id "jane-doe-testconf-2024")
    end
  end

  test "old_id does not affect validation" do
    videos = [
      {"id" => "jane-doe-testconf-2024", "old_id" => "jane-doe-somewhere-else", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "does not expect an id that is reserved as another talk's old_id" do
    videos = [
      {"id" => "jane-doe-lightning-talk-testconf-2024", "old_id" => "jane-doe-testconf-2024", "title" => "Lightning Talk: Tiny Things", "speakers" => ["Jane Doe"]},
      {"id" => "building-things-testconf-2024", "old_id" => "jane-doe-building-things", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "ignores talks at meetup events" do
    videos = [
      {"id" => "some-freeform-meetup-id", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos, event: {"kind" => "meetup"}) do |path|
      assert_empty Static::Validators::TalkId.new(file_path: path).errors
    end
  end

  test "expected_ids maps every talk to the id it should have" do
    videos = [
      {"id" => "wrong", "title" => "Building Things", "speakers" => ["Jane Doe"]}
    ]

    with_temp_video(videos) do |path|
      expected = Static::Validators::TalkId.new(file_path: path).expected_ids

      assert_equal ["jane-doe-testconf-2024"], expected.values
    end
  end

  private

  def with_temp_video(videos, event: nil)
    dir = Dir.mktmpdir
    videos_path = File.join(dir, "data", "testconf", "testconf-2024", "videos.yml")
    FileUtils.mkdir_p(File.dirname(videos_path))
    File.write(videos_path, videos.to_yaml)
    File.write(File.join(File.dirname(videos_path), "event.yml"), event.to_yaml) if event
    yield videos_path
  ensure
    FileUtils.rm_rf(dir)
  end
end
